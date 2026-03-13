use rustler::{Atom, Error, NifResult};
use tree_sitter::{Parser};
use neo4rs::{Graph, query, ConfigBuilder};
use std::sync::Arc;
use tokio::runtime::Runtime;

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

lazy_static::lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().unwrap();
}

async fn write_to_memgraph(ast_json: String) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let uri = "127.0.0.1:7687";
    let user = "";
    let pass = "";
    
    // Explicitly configure neo4rs to not use 'neo4j' database if possible.
    // Memgraph handles Bolt connections but is sensitive to the database field in the BEGIN message.
    let config = ConfigBuilder::default()
        .uri(uri)
        .user(user)
        .password(pass)
        .db("memgraph") // Trying 'memgraph' explicitly
        .build()?;
    
    let graph = Graph::connect(config).await?;
    
    let q = query("CREATE (n:AST {content: $content})").param("content", ast_json);
    graph.run(q).await?;
    Ok(())
}

#[rustler::nif(schedule = "DirtyIo")]
fn parse_and_store(script: String) -> NifResult<(Atom, String)> {
    let mut parser = Parser::new();
    let language = tree_sitter_json::language();
    parser.set_language(language).map_err(|_| Error::Term(Box::new("language_error")))?;
    
    let _tree = parser.parse(&script, None).ok_or(Error::Term(Box::new("parse_error")))?;
    
    match RUNTIME.block_on(write_to_memgraph(script)) {
        Ok(_) => Ok((atoms::ok(), "".to_string())),
        Err(e) => {
            let err_msg = format!("{:?}", e);
            eprintln!("[Rhizome NIF Error] Memgraph storage failed: {}", err_msg);
            Ok((atoms::error(), err_msg))
        }
    }
}

rustler::init!("Elixir.Rhizome.Nif", [parse_and_store]);
