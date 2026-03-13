use serde::{Deserialize, Serialize};
use reqwest::blocking::Client;

#[derive(Serialize, Deserialize, Debug)]
pub struct XtdbPayload {
    #[serde(rename = "xt/id")]
    pub id: String,
    pub data: serde_json::Value,
}

pub struct XtdbClient {
    client: Client,
    url: String,
}

impl XtdbClient {
    pub fn new(url: String) -> Self {
        Self {
            client: Client::new(),
            url,
        }
    }

    pub fn submit_tx(&self, payload: XtdbPayload) -> Result<(), reqwest::Error> {
        // Implementation for XTDB submit-tx endpoint
        Ok(())
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_submit(id: String, data: String) -> String {
    format!("Mock XTDB submission for {}: {}", id, data)
}
