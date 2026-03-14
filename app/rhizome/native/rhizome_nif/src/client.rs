use neo4rs::*;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::Mutex;

lazy_static::lazy_static! {
    pub static ref RUNTIME: Runtime = Runtime::new().unwrap();
    pub static ref CLIENT: Mutex<Option<Arc<MemgraphClient>>> = Mutex::new(None);
}

pub struct MemgraphClient {
    pub graph: Graph,
}

impl MemgraphClient {
    pub async fn new(uri: &str, user: &str, pass: &str) -> Result<Self, Error> {
        let graph = Graph::new(uri, user, pass).await?;
        Ok(Self { graph })
    }

    pub async fn execute_query(&self, q: &str) -> Result<(), Error> {
        self.graph.run(query(q)).await?;
        Ok(())
    }
}

pub struct XtdbClient {
    pub client: reqwest::Client,
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
        Self {
            client: reqwest::Client::new(),
            url,
        }
    }

    pub async fn submit_tx(&self, id: String, data: serde_json::Value) -> Result<String, reqwest::Error> {
        let payload = XtdbPayload { id, data };
        let body = serde_json::json!({
            "tx-ops": [["put", payload]]
        });

        let res = self.client.post(format!("{}/_xtdb/submit-tx", self.url))
            .json(&body)
            .send()
            .await?;
        
        Ok(res.text().await?)
    }
}
