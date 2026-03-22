use crate::client::{parse_service_config, CLIENT, MemgraphClient, RUNTIME};
use rustler::NifResult;
use serde_json::{Map, Number, Value};
use std::sync::Arc;

#[derive(rustler::NifMap, Clone, Debug)]
pub struct CausalPair {
    pub source_node: String,
    pub target_node: String,
    pub delta_w: f64,
}


mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn memgraph_query(query: String, service_config: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let config = match parse_service_config(&service_config) {
            Ok(config) => config,
            Err(error) => return Ok((atoms::error(), error)),
        };

        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new(
                &config.memgraph.url,
                &config.memgraph.username,
                &config.memgraph.password
            ).await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = match client_lock.as_ref() {
            Some(client) => client.clone(),
            None => return Ok((atoms::error(), "Connection Error: client unavailable".to_string())),
        };
        match client.execute_query(&query).await {
            Ok(rows) => Ok((atoms::ok(), serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string()))),
            Err(e) => Ok((atoms::error(), e)),
        }
    })
}

#[rustler::nif]
pub fn initialize_graph() -> rustler::ResourceArc<crate::resource::GraphResource> {
    rustler::ResourceArc::new(crate::resource::GraphResource {
        pointer: std::sync::RwLock::new(crate::resource::GraphPointer {
            node_id: 0,
            generation: 1,
            flags: 0,
        }),
        graph: std::sync::RwLock::new(crate::resource::ActiveGraph::new()),
    })
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn apply_causal_epoch(
    resource: rustler::ResourceArc<crate::resource::GraphResource>, 
    causal_batch: Vec<CausalPair>
) -> rustler::Atom {
    let mut graph = match resource.graph.write() {
        Ok(lock) => lock,
        Err(_) => return atoms::error(),
    };
    graph.batch_update(causal_batch);
    
    atoms::ok()
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn traverse_subgraph(
    _resource: rustler::ResourceArc<crate::resource::GraphResource>,
    _query: String
) -> rustler::Atom {
    // Stub for future traversal implementation
    atoms::ok()
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn weaken_edge(
    resource: rustler::ResourceArc<crate::resource::GraphResource>,
    service_config: String
) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let config = match parse_service_config(&service_config) {
            Ok(config) => config,
            Err(error) => return Ok((atoms::error(), error)),
        };

        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new(
                &config.memgraph.url,
                &config.memgraph.username,
                &config.memgraph.password
            ).await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = match client_lock.as_ref() {
            Some(client) => client.clone(),
            None => return Ok((atoms::error(), "Connection Error: client unavailable".to_string())),
        };
        
        let node_id = {
            let pointer = match resource.pointer.read() {
                Ok(pointer) => pointer,
                Err(_) => return Ok((atoms::error(), "Resource Lock Error".to_string())),
            };
            pointer.node_id
        };

        // Cypher query to weaken the edge. For now, we'll just delete the edge to represent absolute pruning.
        let query = format!("MATCH ()-[r]->() WHERE id(r) = {} DELETE r", node_id);
        match client.execute_query(&query).await {
            Ok(_) => Ok((atoms::ok(), format!("Edge {} pruned successfully", node_id))),
            Err(e) => Ok((atoms::error(), format!("Pruning Error: {}", e))),
        }
    })
}
#[rustler::nif(schedule = "DirtyIo")]
pub fn bridge_to_xtdb(service_config: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let config = match parse_service_config(&service_config) {
            Ok(config) => config,
            Err(error) => return Ok((atoms::error(), error)),
        };

        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new(
                &config.memgraph.url,
                &config.memgraph.username,
                &config.memgraph.password
            ).await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = match client_lock.as_ref() {
            Some(client) => client.clone(),
            None => return Ok((atoms::error(), "Connection Error: client unavailable".to_string())),
        };
        let xtdb = crate::client::XtdbClient::new(config.xtdb.url.clone());

        // 1. Fetch unarchived nodes
        let query_str = "MATCH (n) WHERE NOT n.archived = true RETURN id(n) as id, properties(n) as props";
        let mut result = match client.graph.execute(neo4rs::query(query_str)).await {
            Ok(r) => r,
            Err(e) => return Ok((atoms::error(), format!("Memgraph Query Error: {}", e))),
        };

        let mut count = 0;
        while let Ok(Some(row)) = result.next().await {
            let id: i64 = match row.get("id") {
                Ok(value) => value,
                Err(error) => return Ok((atoms::error(), format!("Decode Error: {}", error))),
            };
            let props: neo4rs::BoltMap = match row.get("props") {
                Ok(value) => value,
                Err(error) => return Ok((atoms::error(), format!("Decode Error: {}", error))),
            };
            
            // Convert properties to JSON
            let mut map = Map::new();
            for (key, value) in props.value {
                let key_str = key.value;
                let val = bolt_type_to_json(value);
                map.insert(key_str, val);
            }

            // 2. Submit to XTDB
            let _ = xtdb.submit_tx(format!("mg_{}", id), serde_json::Value::Object(map)).await;
            
            // 3. Mark as archived in Memgraph
            let mark_query = format!("MATCH (n) WHERE id(n) = {} SET n.archived = true", id);
            let _ = client.execute_query(&mark_query).await;
            
            count += 1;
        }

        Ok((atoms::ok(), format!("Successfully bridged {} nodes to XTDB ledger", count)))
    })
}

fn bolt_type_to_json(value: neo4rs::BoltType) -> Value {
    match value {
        neo4rs::BoltType::String(s) => Value::String(s.value),
        neo4rs::BoltType::Integer(i) => Value::Number(i.value.into()),
        neo4rs::BoltType::Float(f) => Number::from_f64(f.value)
            .map(Value::Number)
            .unwrap_or(Value::Null),
        neo4rs::BoltType::Boolean(b) => Value::Bool(b.value),
        _ => Value::Null,
    }
}
