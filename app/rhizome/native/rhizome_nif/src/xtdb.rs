use crate::client::{parse_service_config, RUNTIME, XtdbClient};
use rustler::NifResult;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_submit(id: String, data: String, service_config: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let config = match parse_service_config(&service_config) {
            Ok(config) => config,
            Err(error) => return Ok((atoms::error(), error)),
        };
        let client = XtdbClient::new(config.xtdb.url);
        
        match serde_json::from_str::<serde_json::Value>(&data) {
            Ok(json) => {
                match client.submit_tx(id, json).await {
                    Ok(resp) => Ok((atoms::ok(), serde_json::to_string(&resp).unwrap_or_else(|_| "{}".to_string()))),
                    Err(e) => Ok((atoms::error(), format!("XTDB Error: {}", e))),
                }
            },
            Err(e) => Ok((atoms::error(), format!("JSON Parse Error: {}", e))),
        }
    })
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn xtdb_query(query: String, service_config: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let config = match parse_service_config(&service_config) {
            Ok(config) => config,
            Err(error) => return Ok((atoms::error(), error)),
        };
        let client = XtdbClient::new(config.xtdb.url);
        
        match serde_json::from_str::<serde_json::Value>(&query) {
            Ok(json) => {
                match client.query(json).await {
                    Ok(resp) => Ok((atoms::ok(), serde_json::to_string(&resp).unwrap_or_else(|_| "[]".to_string()))),
                    Err(e) => Ok((atoms::error(), format!("XTDB Error: {}", e))),
                }
            },
            Err(e) => Ok((atoms::error(), format!("JSON Parse Error: {}", e))),
        }
    })
}
