use neo4rs::*;
use serde_json::Value;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::Mutex;

lazy_static::lazy_static! {
    pub static ref RUNTIME: Runtime = Runtime::new().unwrap();
    pub static ref CLIENT: Mutex<Option<Arc<MemgraphClient>>> = Mutex::new(None);
    pub static ref XTDB_REQ_CLIENT: reqwest::Client = reqwest::Client::new();
}

pub struct MemgraphClient {
    pub graph: Graph,
}

#[derive(Clone, Debug, serde::Deserialize)]
pub struct MemgraphConfig {
    pub url: String,
    pub username: String,
    pub password: String,
}

#[derive(Clone, Debug, serde::Deserialize)]
pub struct XtdbConfig {
    pub url: String,
}

#[derive(Clone, Debug, serde::Deserialize)]
pub struct ServiceConfig {
    pub memgraph: MemgraphConfig,
    pub xtdb: XtdbConfig,
}

impl MemgraphClient {
    pub async fn new(uri: &str, user: &str, pass: &str) -> Result<Self, Error> {
        let config = ConfigBuilder::new()
            .uri(uri)
            .user(user)
            .password(pass)
            .db("memgraph") // Explicitly use 'memgraph' database
            .build()?;
        let graph = Graph::connect(config).await?;
        Ok(Self { graph })
    }

    pub async fn execute_query(&self, q: &str) -> Result<Vec<Value>, String> {
        let mut result = self
            .graph
            .execute(query(q))
            .await
            .map_err(|e| format!("Query Error: {}", e))?;

        let mut rows = Vec::new();
        while let Ok(Some(row)) = result.next().await {
            let value: Value = row
                .to()
                .map_err(|e| format!("Decode Error: {}", e))?;
            rows.push(value);
        }

        Ok(rows)
    }
}

pub struct XtdbClient {
    pub url: String,
}

#[derive(serde::Serialize, serde::Deserialize, Debug)]
pub struct XtdbPayload {
    #[serde(rename = "xt/id")]
    pub id: String,
    pub data: serde_json::Value,
}

impl XtdbClient {
    pub fn new(url: String) -> Self {
        Self { url }
    }

    pub async fn submit_tx(&self, id: String, data: serde_json::Value) -> Result<Value, reqwest::Error> {
        let payload = XtdbPayload { id, data };
        let body = serde_json::json!({
            "tx-ops": [["put", payload]]
        });

        let res = XTDB_REQ_CLIENT.post(format!("{}/tx", self.url))
            .json(&body)
            .send()
            .await?
            .error_for_status()?;

        res.json().await
    }

    pub async fn query(&self, query: serde_json::Value) -> Result<Value, reqwest::Error> {
        let res = XTDB_REQ_CLIENT.post(format!("{}/query", self.url))
            .json(&query)
            .header("Accept", "application/json")
            .header("Content-Type", "application/json")
            .send()
            .await?
            .error_for_status()?;

        res.json().await
    }
}

pub fn parse_service_config(config_json: &str) -> Result<ServiceConfig, String> {
    serde_json::from_str(config_json).map_err(|e| format!("Invalid service config: {}", e))
}
