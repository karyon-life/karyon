use crate::client::{CLIENT, RUNTIME};
use neo4rs::*;
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};
use rustler::NifResult;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

use single_clustering::network::CSRNetwork;
use single_clustering::network::grouping::VectorGrouping;
use single_clustering::community_search::leiden::{LeidenOptimizer, LeidenConfig};
use single_clustering::community_search::leiden::partition::{VertexPartition, ModularityPartition};

pub fn identify_communities(edges: Vec<(usize, usize, f64)>, node_count: usize) -> Result<Vec<Vec<usize>>, String> {
    if edges.is_empty() {
        return Ok(Vec::new());
    }
    
    let network = CSRNetwork::from_edges(&edges, vec![1.0; node_count]);
    let mut optimizer = LeidenOptimizer::new(LeidenConfig::default());

    let partition: ModularityPartition<f64, VectorGrouping> = optimizer
        .find_partition(network)
        .map_err(|error| format!("Partition Error: {}", error))?;

    Ok(partition.get_communities())
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

        // 1. Fetch all nodes and edges from Memgraph
        let mut result = match client.graph.execute(query("MATCH (n)-[r]->(m) RETURN id(n) as start, id(m) as end, coalesce(r.weight, 1.0) as weight")).await {
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
            return (atoms::ok(), "Sleep Cycle: No graph data found to consolidate.".to_string());
        }

        let node_count = next_internal_id;

        // 2. Identify communities using Leiden
        let communities = match identify_communities(edge_list, node_count) {
            Ok(communities) => communities,
            Err(error) => return (atoms::error(), error),
        };
        let community_count = communities.len();

        // 3. Super-Node Generation
        for (i, community) in communities.iter().enumerate() {
            if community.len() > 1 {
                let now = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|duration| duration.as_secs())
                    .unwrap_or(0);
                let super_node_id = format!("sn_{}_{}", now, i);
                
                // Calculate confidence based on cluster density/size
                // Simplified: confidence = log2(size) / 10.0 (capped at 1.0)
                let confidence = ((community.len() as f64).log2() / 10.0).min(1.0);

                // Create SuperNode with confidence
                let _ = client.graph.run(query("CREATE (s:SuperNode {id: $id, type: 'COMMUNITY', confidence: $conf})")
                    .param("id", super_node_id.clone())
                    .param("conf", confidence)).await;

                for internal_id in community {
                    if let Some(external_id) = internal_id_to_external.get(internal_id) {
                        // Link member to SuperNode
                        let _ = client.graph.run(query("MATCH (s:SuperNode {id: $sn_id}), (m) WHERE id(m) = $m_id CREATE (m)-[:MEMBER_OF]->(s)")
                            .param("sn_id", super_node_id.clone())
                            .param("m_id", *external_id as i64)).await;
                    }
                }
            }
        }
        
        (atoms::ok(), format!("Optimization complete: identified {} communities and generated Super-Nodes.", community_count))
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

        let communities = identify_communities(edges, node_count).unwrap();
        assert_eq!(communities.len(), 1);
        assert_eq!(communities[0].len(), 2);
    }

    #[test]
    fn test_identify_communities_disjoint() {
        let edges = vec![];
        let node_count = 2;

        let communities = identify_communities(edges, node_count).unwrap();
        // If there are no edges, it returns empty Vec or 1-node communities?
        // Let's check implementation: if edges.is_empty() { return Vec::new(); }
        assert_eq!(communities.len(), 0);
    }
}
