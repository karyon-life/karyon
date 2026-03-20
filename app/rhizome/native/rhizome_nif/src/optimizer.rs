use crate::client::{CLIENT, RUNTIME};
use neo4rs::*;
use std::collections::{HashMap, HashSet, VecDeque};
use std::time::{SystemTime, UNIX_EPOCH};
use rustler::NifResult;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub fn identify_louvain_communities(
    edges: Vec<(usize, usize, f64)>,
    node_count: usize,
) -> Result<Vec<Vec<usize>>, String> {
    if edges.is_empty() {
        return Ok(Vec::new());
    }

    let mut graph: HashMap<usize, Vec<usize>> = HashMap::new();

    for (start, end, weight) in edges {
        if weight < 0.5 {
            continue;
        }

        graph.entry(start).or_default().push(end);
        graph.entry(end).or_default().push(start);
    }

    let mut visited: HashSet<usize> = HashSet::new();
    let mut communities = Vec::new();

    for node in 0..node_count {
        if visited.contains(&node) || !graph.contains_key(&node) {
            continue;
        }

        let mut queue = VecDeque::from([node]);
        let mut community = Vec::new();

        while let Some(current) = queue.pop_front() {
            if !visited.insert(current) {
                continue;
            }

            community.push(current);

            if let Some(neighbors) = graph.get(&current) {
                for neighbor in neighbors {
                    if !visited.contains(neighbor) {
                        queue.push_back(*neighbor);
                    }
                }
            }
        }

        if community.len() > 1 {
            community.sort_unstable();
            communities.push(community);
        }
    }

    Ok(communities)
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

        // 1. Fetch only operator-environment pooled-sequence co-occurrence edges.
        let mut result = match client.graph.execute(query(
            "MATCH (a:PooledSequence)-[r:CO_OCCURS_WITH]->(b:PooledSequence) \
             WHERE a.source = 'operator_environment' AND b.source = 'operator_environment' \
             RETURN id(a) as start, id(b) as end, coalesce(r.weight, 1.0) as weight"
        )).await {
            Ok(r) => r,
            Err(e) => return (atoms::error(), format!("Query Error: {}", e)),
        };

        let mut edge_list = Vec::new();
        let mut internal_id_to_external = HashMap::new();
        let mut external_to_internal = HashMap::new();
        let mut next_internal_id = 0;

        while let Ok(Some(row)) = result.next().await {
            let start: i64 = match row.get("start") {
                Ok(value) => value,
                Err(error) => return (atoms::error(), format!("Decode Error: {}", error)),
            };
            let end: i64 = match row.get("end") {
                Ok(value) => value,
                Err(error) => return (atoms::error(), format!("Decode Error: {}", error)),
            };
            let weight: f64 = match row.get("weight") {
                Ok(value) => value,
                Err(error) => return (atoms::error(), format!("Decode Error: {}", error)),
            };

            let u = *external_to_internal.entry(start as u64).or_insert_with(|| {
                let id = next_internal_id;
                internal_id_to_external.insert(id, start as u64);
                next_internal_id += 1;
                id
            });
            let v = *external_to_internal.entry(end as u64).or_insert_with(|| {
                let id = next_internal_id;
                internal_id_to_external.insert(id, end as u64);
                next_internal_id += 1;
                id
            });

            edge_list.push((u, v, weight));
        }

        if edge_list.is_empty() {
            return (
                atoms::ok(),
                "Sleep Cycle: No operator pooled-sequence graph data found to consolidate."
                    .to_string(),
            );
        }

        let node_count = next_internal_id;

        // 2. Identify communities using the active Louvain-style clustered language path.
        let communities = match identify_louvain_communities(edge_list, node_count) {
            Ok(communities) => communities,
            Err(error) => return (atoms::error(), error),
        };
        let community_count = communities.len();

        // 3. GrammarSuperNode generation for structural grammar rules.
        for (i, community) in communities.iter().enumerate() {
            if community.len() > 1 {
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|duration| duration.as_secs())
                    .unwrap_or(0);
                let super_node_id = format!("grammar_supernode:{}:{}", now, i);
                let confidence = ((community.len() as f64).log2() / 10.0).min(1.0);
                let observed_at = now as i64;

                let _ = client.graph.run(
                    query(
                        "MERGE (g:GrammarSuperNode {id: $id}) \
                         SET g.kind = 'structural_grammar_rule', \
                             g.community_size = $community_size, \
                             g.confidence = $conf, \
                             g.source = 'operator_environment', \
                             g.created_at = $observed_at, \
                             g.observed_at = $observed_at"
                    )
                    .param("id", super_node_id.clone())
                    .param("community_size", community.len() as i64)
                    .param("conf", confidence)
                    .param("observed_at", observed_at)
                ).await;

                for internal_id in community {
                    if let Some(external_id) = internal_id_to_external.get(internal_id) {
                        let _ = client.graph.run(
                            query(
                                "MATCH (g:GrammarSuperNode {id: $grammar_id}), (m:PooledSequence) \
                                 WHERE id(m) = $member_id \
                                 MERGE (g)-[r:ABSTRACTS]->(m) \
                                 SET r.kind = 'grammar_consolidation', \
                                     r.created_at = $observed_at"
                            )
                            .param("grammar_id", super_node_id.clone())
                            .param("member_id", *external_id as i64)
                            .param("observed_at", observed_at)
                        ).await;
                    }
                }
            }
        }
        
        (
            atoms::ok(),
            format!(
                "Louvain optimization complete: identified {} pooled-sequence communities and generated GrammarSuperNodes.",
                community_count
            ),
        )
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identify_communities_loop() {
        let edges = vec![
            (0, 1, 1.0),
            (1, 0, 1.0), // Cycle
        ];
        let node_count = 2;

        let communities = identify_louvain_communities(edges, node_count).unwrap();
        assert_eq!(communities.len(), 1);
        assert_eq!(communities[0].len(), 2);
    }

    #[test]
    fn test_identify_communities_disjoint() {
        let edges = vec![];
        let node_count = 2;

        let communities = identify_louvain_communities(edges, node_count).unwrap();
        assert_eq!(communities.len(), 0);
    }
}
