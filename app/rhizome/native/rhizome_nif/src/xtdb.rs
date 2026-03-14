use serde::{Deserialize, Serialize};
use reqwest::blocking::Client;
use rustler::NifResult;

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

    pub fn submit_tx(&self, id: String, data: serde_json::Value) -> Result<String, reqwest::Error> {
        let payload = XtdbPayload { id, data };
        let body = serde_json::json!({
            "tx-ops": [["put", payload]]
        });

        let res = self.client.post(format!("{}/_xtdb/submit-tx", self.url))
            .json(&body)
            .send()?;
        
        Ok(res.text()?)
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_submit(id: String, data: String) -> NifResult<String> {
    let client = XtdbClient::new("http://127.0.0.1:3000".to_string());
    
    match serde_json::from_str(&data) {
        Ok(json) => {
            match client.submit_tx(id, json) {
                Ok(resp) => Ok(resp),
                Err(e) => Ok(format!("XTDB Error: {}", e)),
            }
        },
        Err(e) => Ok(format!("JSON Parse Error: {}", e)),
    }
}
