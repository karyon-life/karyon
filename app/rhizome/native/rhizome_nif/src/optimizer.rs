use crate::client::{CLIENT, RUNTIME};
use neo4rs::*;
use rustler::NifResult;
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

const MIN_SUPPORT: f64 = 2.0;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct TemporalTriple {
    pub start_id: u64,
    pub middle_id: u64,
    pub end_id: u64,
    pub ab_weight: f64,
    pub bc_weight: f64,
    pub ab_occurrences: f64,
    pub bc_occurrences: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TemporalChunk {
    pub ordered_ids: [u64; 3],
    pub support: f64,
    pub observations: u64,
}

#[derive(Default)]
struct ChunkAggregate {
    support: f64,
    observations: u64,
}

pub fn sequential_pairwise_chunking(
    triples: Vec<TemporalTriple>,
    min_support: f64,
) -> Vec<TemporalChunk> {
    let mut aggregates: HashMap<(u64, u64, u64), ChunkAggregate> = HashMap::new();

    for triple in triples {
        let key = (triple.start_id, triple.middle_id, triple.end_id);
        let local_support = support_for_triple(&triple);

        let aggregate = aggregates.entry(key).or_default();
        aggregate.support += local_support;
        aggregate.observations += 1;
    }

    let mut chunks: Vec<_> = aggregates
        .into_iter()
        .filter_map(|((start_id, middle_id, end_id), aggregate)| {
            if aggregate.support >= min_support {
                Some(TemporalChunk {
                    ordered_ids: [start_id, middle_id, end_id],
                    support: round_support(aggregate.support),
                    observations: aggregate.observations,
                })
            } else {
                None
            }
        })
        .collect();

    chunks.sort_by(|left, right| {
        right
            .support
            .total_cmp(&left.support)
            .then_with(|| left.ordered_ids.cmp(&right.ordered_ids))
    });

    chunks
}

fn support_for_triple(triple: &TemporalTriple) -> f64 {
    let mean_weight = (triple.ab_weight + triple.bc_weight) / 2.0;
    let mean_occurrences = (triple.ab_occurrences + triple.bc_occurrences) / 2.0;
    mean_weight * mean_occurrences
}

fn round_support(value: f64) -> f64 {
    (value * 1000.0).round() / 1000.0
}

fn sequence_signature(ordered_ids: [u64; 3]) -> String {
    format!("{}>{}>{}", ordered_ids[0], ordered_ids[1], ordered_ids[2])
}

fn decode_float(row: &Row, key: &str) -> Result<f64, String> {
    if let Ok(value) = row.get::<f64>(key) {
        Ok(value)
    } else if let Ok(value) = row.get::<i64>(key) {
        Ok(value as f64)
    } else {
        Err(format!("Decode Error: missing numeric field {}", key))
    }
}

fn decode_i64(row: &Row, key: &str) -> Result<i64, String> {
    row.get::<i64>(key)
        .map_err(|error| format!("Decode Error: {}", error))
}

async fn persist_temporal_chunk(
    client: &crate::client::MemgraphClient,
    chunk: &TemporalChunk,
    observed_at: i64,
) -> Result<(), String> {
    let grammar_id = format!("grammar_supernode:{}", sequence_signature(chunk.ordered_ids));
    let sequence_signature = sequence_signature(chunk.ordered_ids);

    let grammar_query = query(
        "MERGE (g:GrammarSuperNode {id: $id}) \
         SET g.kind = 'temporal_grammar_chunk', \
             g.source = 'operator_environment', \
             g.sequence_length = $sequence_length, \
             g.support = $support, \
             g.observations = $observations, \
             g.sequence_signature = $sequence_signature, \
             g.start_member_id = $start_member_id, \
             g.middle_member_id = $middle_member_id, \
             g.end_member_id = $end_member_id, \
             g.created_at = coalesce(g.created_at, $observed_at), \
             g.observed_at = $observed_at",
    )
    .param("id", grammar_id.clone())
    .param("sequence_length", 3_i64)
    .param("support", chunk.support)
    .param("observations", chunk.observations as i64)
    .param("sequence_signature", sequence_signature)
    .param("start_member_id", chunk.ordered_ids[0] as i64)
    .param("middle_member_id", chunk.ordered_ids[1] as i64)
    .param("end_member_id", chunk.ordered_ids[2] as i64)
    .param("observed_at", observed_at);

    client
        .graph
        .run(grammar_query)
        .await
        .map_err(|error| format!("Persistence Error: {}", error))?;

    for (position, member_id) in chunk.ordered_ids.iter().enumerate() {
        let abstraction_query = query(
            "MATCH (g:GrammarSuperNode {id: $grammar_id}), (m:PooledSequence) \
             WHERE id(m) = $member_id \
             MERGE (g)-[r:ABSTRACTS]->(m) \
             SET r.kind = 'grammar_consolidation', \
                 r.position = $position, \
                 r.created_at = coalesce(r.created_at, $observed_at), \
                 r.observed_at = $observed_at",
        )
        .param("grammar_id", grammar_id.clone())
        .param("member_id", *member_id as i64)
        .param("position", position as i64)
        .param("observed_at", observed_at);

        client
            .graph
            .run(abstraction_query)
            .await
            .map_err(|error| format!("Persistence Error: {}", error))?;
    }

    Ok(())
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn optimize_graph() -> NifResult<(rustler::Atom, String)> {
    Ok(RUNTIME.block_on(async {
        let client_lock = CLIENT.lock().await;
        if client_lock.is_none() {
            return (atoms::error(), "Error: Memgraph client not initialized".to_string());
        }

        let client = match client_lock.as_ref() {
            Some(client) => client,
            None => return (atoms::error(), "Error: Memgraph client unavailable".to_string()),
        };

        let mut result = match client
            .graph
            .execute(query(
                "MATCH (a:PooledSequence)-[ab:FOLLOWED_BY]->(b:PooledSequence)-[bc:FOLLOWED_BY]->(c:PooledSequence) \
                 WHERE a.source = 'operator_environment' \
                   AND b.source = 'operator_environment' \
                   AND c.source = 'operator_environment' \
                 RETURN id(a) AS start_id, \
                        id(b) AS middle_id, \
                        id(c) AS end_id, \
                        coalesce(ab.weight, 1.0) AS ab_weight, \
                        coalesce(bc.weight, 1.0) AS bc_weight, \
                        coalesce(ab.occurrences, 1) AS ab_occurrences, \
                        coalesce(bc.occurrences, 1) AS bc_occurrences"
            ))
            .await
        {
            Ok(result) => result,
            Err(error) => return (atoms::error(), format!("Query Error: {}", error)),
        };

        let mut triples = Vec::new();

        loop {
            match result.next().await {
                Ok(Some(row)) => {
                    let triple = match (
                        decode_i64(&row, "start_id"),
                        decode_i64(&row, "middle_id"),
                        decode_i64(&row, "end_id"),
                        decode_float(&row, "ab_weight"),
                        decode_float(&row, "bc_weight"),
                        decode_float(&row, "ab_occurrences"),
                        decode_float(&row, "bc_occurrences"),
                    ) {
                        (
                            Ok(start_id),
                            Ok(middle_id),
                            Ok(end_id),
                            Ok(ab_weight),
                            Ok(bc_weight),
                            Ok(ab_occurrences),
                            Ok(bc_occurrences),
                        ) => TemporalTriple {
                            start_id: start_id as u64,
                            middle_id: middle_id as u64,
                            end_id: end_id as u64,
                            ab_weight,
                            bc_weight,
                            ab_occurrences,
                            bc_occurrences,
                        },
                        (Err(error), _, _, _, _, _, _)
                        | (_, Err(error), _, _, _, _, _)
                        | (_, _, Err(error), _, _, _, _)
                        | (_, _, _, Err(error), _, _, _)
                        | (_, _, _, _, Err(error), _, _)
                        | (_, _, _, _, _, Err(error), _)
                        | (_, _, _, _, _, _, Err(error)) => return (atoms::error(), error),
                    };

                    triples.push(triple);
                }
                Ok(None) => break,
                Err(error) => return (atoms::error(), format!("Query Error: {}", error)),
            }
        }

        if triples.is_empty() {
            return (
                atoms::ok(),
                "Sleep Cycle: No operator FOLLOWED_BY temporal path data found to consolidate."
                    .to_string(),
            );
        }

        let chunks = sequential_pairwise_chunking(triples, MIN_SUPPORT);

        if chunks.is_empty() {
            return (
                atoms::ok(),
                "Sleep Cycle: No high-support temporal sequence candidates found to consolidate."
                    .to_string(),
            );
        }

        let observed_at = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_secs() as i64)
            .unwrap_or(0);

        for chunk in &chunks {
            if let Err(error) = persist_temporal_chunk(client, chunk, observed_at).await {
                return (atoms::error(), error);
            }
        }

        (
            atoms::ok(),
            format!(
                "Temporal chunking complete: created {} ordered grammar chunks from FOLLOWED_BY paths.",
                chunks.len()
            ),
        )
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn support_accumulates_for_repeated_ordered_sequences() {
        let chunks = sequential_pairwise_chunking(
            vec![
                TemporalTriple {
                    start_id: 1,
                    middle_id: 2,
                    end_id: 3,
                    ab_weight: 1.0,
                    bc_weight: 1.0,
                    ab_occurrences: 2.0,
                    bc_occurrences: 2.0,
                },
                TemporalTriple {
                    start_id: 1,
                    middle_id: 2,
                    end_id: 3,
                    ab_weight: 1.0,
                    bc_weight: 1.0,
                    ab_occurrences: 2.0,
                    bc_occurrences: 2.0,
                },
            ],
            2.0,
        );

        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].ordered_ids, [1, 2, 3]);
        assert_eq!(chunks[0].observations, 2);
        assert_eq!(chunks[0].support, 4.0);
    }

    #[test]
    fn support_ignores_low_signal_triples() {
        let chunks = sequential_pairwise_chunking(
            vec![TemporalTriple {
                start_id: 1,
                middle_id: 2,
                end_id: 3,
                ab_weight: 0.5,
                bc_weight: 0.5,
                ab_occurrences: 1.0,
                bc_occurrences: 1.0,
            }],
            2.0,
        );

        assert!(chunks.is_empty());
    }
}
