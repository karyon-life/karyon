use neo4rs::*;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::Mutex;
use rustler::NifResult;

lazy_static::lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().unwrap();
    static ref CLIENT: Mutex<Option<Arc<MemgraphClient>>> = Mutex::new(None);
}

pub struct MemgraphClient {
    graph: Graph,
}

impl MemgraphClient {
    pub async fn new(uri: &str, user: &str, pass: &str) -> Result<Self, Error> {
        let config = ConfigBuilder::default()
            .uri(uri)
            .user(user)
            .password(pass)
            .build()
            .unwrap();
        let graph = Graph::new(config).await?;
        Ok(Self { graph })
    }

    pub async fn execute_query(&self, query: &str) -> Result<(), Error> {
        self.graph.run(query!(query)).await?;
        Ok(())
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn memgraph_query(query: String) -> NifResult<String> {
    RUNTIME.block_on(async {
        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            // Default connection params for MVP; in production these would come from config
            match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok(format!("Connection Error: {}", e)),
            }
        }

        let client = client_lock.as_ref().unwrap().clone();
        match client.execute_query(&query).await {
            Ok(_) => Ok("Query executed successfully".to_string()),
            Err(e) => Ok(format!("Query Error: {}", e)),
        }
    })
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn weaken_edge(id: String) -> NifResult<String> {
    RUNTIME.block_on(async {
        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok(format!("Connection Error: {}", e)),
            }
        }

        let client = client_lock.as_ref().unwrap().clone();
        // Cypher query to weaken the edge. For now, we'll just delete the edge to represent absolute pruning.
        let query = format!("MATCH ()-[r]->() WHERE id(r) = {} DELETE r", id);
        match client.execute_query(&query).await {
            Ok(_) => Ok(format!("Edge {} pruned successfully", id)),
            Err(e) => Ok(format!("Pruning Error: {}", e)),
        }
    })
}
