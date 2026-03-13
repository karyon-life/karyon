use neo4rs::*;
use std::sync::Arc;
use tokio::runtime::Runtime;

lazy_static::lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().unwrap();
}

pub struct MemgraphClient {
    graph: Arc<Graph>,
}

impl MemgraphClient {
    pub async fn new(uri: &str, user: &str, pass: &str) -> Result<Self, Error> {
        let config = ConfigBuilder::default()
            .uri(uri)
            .user(user)
            .password(pass)
            .build()
            .unwrap();
        let graph = Arc::new(Graph::new(config).await?);
        Ok(Self { graph })
    }

    pub async fn execute_query(&self, query: &str) -> Result<(), Error> {
        self.graph.run(query!(query)).await?;
        Ok(())
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn memgraph_query(query: String) -> String {
    // Blocking execution for the DirtyIo scheduler
    format!("Mock result for query: {}", query)
}
