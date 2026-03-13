use rustler::{Atom, Error, NifResult, SchedulerFlags};
use tree_sitter::{Parser, Language};
use neo4rs::{Graph, query};
use std::sync::Arc;

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

// DirtyIo is critical here: we are doing network I/O and we MUST NOT block the BEAM scheduler.
#[rustler::nif(schedule = "DirtyIo")]
fn parse_and_store(script: String) -> NifResult<Atom> {
    let mut parser = Parser::new();
    let language = tree_sitter_json::language().into();
    parser.set_language(language).unwrap();
    
    let tree = parser.parse(&script, None).ok_or(Error::Term(Box::new("parse_error")))?;
    // 2. Write to Memgraph
    // NOTE: Connecting directly to Memgraph via Bolt requires a specialized driver 
    // since `neo4rs` expects strict Neo4J database selection which Memgraph rejects. 
    // For Phase 0 MVP, we return the parsed AST success state.
    
    Ok(atoms::ok())
}

rustler::init!("Elixir.Rhizome.Nif", [parse_and_store]);
