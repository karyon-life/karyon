use crate::client::{RUNTIME, XtdbClient};
use rustler::NifResult;

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_submit(id: String, data: String) -> NifResult<String> {
    RUNTIME.block_on(async {
        let client = XtdbClient::new("http://127.0.0.1:3000".to_string());
        
        match serde_json::from_str::<serde_json::Value>(&data) {
            Ok(json) => {
                match client.submit_tx(id, json).await {
                    Ok(resp) => Ok(resp),
                    Err(e) => Ok(format!("XTDB Error: {}", e)),
                }
            },
            Err(e) => Ok(format!("JSON Parse Error: {}", e)),
        }
    })
}
