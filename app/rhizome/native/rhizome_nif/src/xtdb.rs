use crate::client::{RUNTIME, XtdbClient};
use rustler::NifResult;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_submit(id: String, data: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let client = XtdbClient::new("http://127.0.0.1:3000".to_string());
        
        match serde_json::from_str::<serde_json::Value>(&data) {
            Ok(json) => {
                match client.submit_tx(id, json).await {
                    Ok(resp) => Ok((atoms::ok(), resp)),
                    Err(e) => Ok((atoms::error(), format!("XTDB Error: {}", e))),
                }
            },
            Err(e) => Ok((atoms::error(), format!("JSON Parse Error: {}", e))),
        }
    })
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_query(query: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let client = XtdbClient::new("http://127.0.0.1:3000".to_string());
        
        match serde_json::from_str::<serde_json::Value>(&query) {
            Ok(json) => {
                match client.query(json).await {
                    Ok(resp) => Ok((atoms::ok(), resp)),
                    Err(e) => Ok((atoms::error(), format!("XTDB Error: {}", e))),
                }
            },
            Err(e) => Ok((atoms::error(), format!("JSON Parse Error: {}", e))),
        }
    })
}
