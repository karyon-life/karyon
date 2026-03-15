use crate::client::{CLIENT, RUNTIME};
use petgraph::graph::{DiGraph, NodeIndex};
use petgraph::algo::tarjan_scc;
use neo4rs::*;
use std::collections::HashMap;
use rustler::NifResult;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub fn identify_communities(graph: &DiGraph<u64, ()>) -> Vec<Vec<NodeIndex>> {
    tarjan_scc(graph)
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn optimize_graph() -> NifResult<(rustler::Atom, String)> {
    Ok(RUNTIME.block_on(async {
        let client_lock = CLIENT.lock().await;
        if client_lock.is_none() {
            return (atoms::error(), "Error: Memgraph client not initialized".to_string());
        }
        let client = client_lock.as_ref().unwrap();

        // 1. Fetch all nodes and edges from Memgraph
        let mut result = match client.graph.execute(query("MATCH (n)-[r]->(m) RETURN id(n) as start, id(m) as end")).await {
            Ok(r) => r,
            Err(e) => return (atoms::error(), format!("Query Error: {}", e)),
        };

        let mut graph = DiGraph::<u64, ()>::new();
        let mut nodes = HashMap::new();

        while let Ok(Some(row)) = result.next().await {
            let start: i64 = row.get("start").unwrap();
            let end: i64 = row.get("end").unwrap();

            let u = *nodes.entry(start as u64).or_insert_with(|| graph.add_node(start as u64));
            let v = *nodes.entry(end as u64).or_insert_with(|| graph.add_node(end as u64));
            graph.add_edge(u, v, ());
        }

        if graph.node_count() == 0 {
            return (atoms::ok(), "Sleep Cycle: No graph data found to consolidate.".to_string());
        }

        // 2. Identify communities
        let scc = identify_communities(&graph);
        let community_count = scc.len();
        
        (atoms::ok(), format!("Optimization complete: identified {} communities", community_count))
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identify_communities_loop() {
        let mut graph = DiGraph::<u64, ()>::new();
        let n1 = graph.add_node(1);
        let n2 = graph.add_node(2);
        graph.add_edge(n1, n2, ());
        graph.add_edge(n2, n1, ()); // Cycle

        let communities = identify_communities(&graph);
        assert_eq!(communities.len(), 1);
        assert_eq!(communities[0].len(), 2);
    }

    #[test]
    fn test_identify_communities_disjoint() {
        let mut graph = DiGraph::<u64, ()>::new();
        graph.add_node(1);
        graph.add_node(2);

        let communities = identify_communities(&graph);
        assert_eq!(communities.len(), 2);
    }
}
