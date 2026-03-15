use crate::client::{CLIENT, RUNTIME, MemgraphClient};
use rustler::NifResult;
use std::sync::Arc;


mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn memgraph_query(query: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            // Default connection params for MVP; in production these would come from config
            match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = client_lock.as_ref().unwrap().clone();
        match client.execute_query(&query).await {
            Ok(_) => Ok((atoms::ok(), "Query executed successfully".to_string())),
            Err(e) => Ok((atoms::error(), format!("Query Error: {}", e))),
        }
    })
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn weaken_edge(id: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = client_lock.as_ref().unwrap().clone();
        // Cypher query to weaken the edge. For now, we'll just delete the edge to represent absolute pruning.
        let query = format!("MATCH ()-[r]->() WHERE id(r) = {} DELETE r", id);
        match client.execute_query(&query).await {
            Ok(_) => Ok((atoms::ok(), format!("Edge {} pruned successfully", id))),
            Err(e) => Ok((atoms::error(), format!("Pruning Error: {}", e))),
        }
    })
}
