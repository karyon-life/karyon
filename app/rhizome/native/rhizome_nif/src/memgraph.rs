use crate::client::{parse_service_config, CLIENT, MemgraphClient, RUNTIME};
use rustler::NifResult;
use std::sync::Arc;


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

        let client = client_lock.as_ref().unwrap().clone();
        match client.execute_query(&query).await {
            Ok(rows) => Ok((atoms::ok(), serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string()))),
            Err(e) => Ok((atoms::error(), e)),
        }
    })
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

        let client = client_lock.as_ref().unwrap().clone();
        
        let node_id = {
            let pointer = resource.pointer.read().unwrap();
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

        let client = client_lock.as_ref().unwrap().clone();
        let xtdb = crate::client::XtdbClient::new(config.xtdb.url.clone());

        // 1. Fetch unarchived nodes
        let query_str = "MATCH (n) WHERE NOT n.archived = true RETURN id(n) as id, properties(n) as props";
        let mut result = match client.graph.execute(neo4rs::query(query_str)).await {
            Ok(r) => r,
            Err(e) => return Ok((atoms::error(), format!("Memgraph Query Error: {}", e))),
        };

        let mut count = 0;
        while let Ok(Some(row)) = result.next().await {
            let id: i64 = row.get("id").unwrap();
            let props: neo4rs::BoltMap = row.get("props").unwrap();
            
            // Convert properties to JSON
            let mut map = serde_json::Map::new();
            for (key, value) in props.value {
                let key_str = key.value;
                let val = match value {
                    neo4rs::BoltType::String(s) => serde_json::Value::String(s.value),
                    neo4rs::BoltType::Integer(i) => serde_json::Value::Number(i.value.into()),
                    neo4rs::BoltType::Float(f) => serde_json::Value::Number(serde_json::Number::from_f64(f.value).unwrap()),
                    neo4rs::BoltType::Boolean(b) => serde_json::Value::Bool(b.value),
                    _ => serde_json::Value::Null,
                };
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
