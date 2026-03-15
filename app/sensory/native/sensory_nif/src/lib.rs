use rustler::{NifResult, Env, Term};
use tree_sitter::{Parser, Node};
use serde_json::{json, Value};
use neo4rs::{Graph, ConfigBuilder, query, Txn, Error};
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
        let config = ConfigBuilder::new()
            .uri(uri)
            .user(user)
            .password(pass)
            .db("memgraph")
            .build()?;
        let graph = Graph::connect(config).await?;
        Ok(Self { graph })
    }
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub fn parse_to_graph_impl(lang_name: String, code: String) -> String {
    let language = match lang_name.as_str() {
        "javascript" => tree_sitter_javascript::language(),
        "python" => tree_sitter_python::language(),
        "c" => tree_sitter_c::language(),
        _ => return "Unsupported language".to_string(),
    };

    let mut parser = Parser::new();
    parser.set_language(language).expect("Error loading language");

    let tree = parser.parse(&code, None).unwrap();
    let root_node = tree.root_node();

    let mut nodes = Vec::new();
    let mut edges = Vec::new();
    
    flatten_node(root_node, &code, &mut nodes, &mut edges);

    let graph_data = json!({
        "nodes": nodes,
        "edges": edges
    });

    serde_json::to_string(&graph_data).unwrap_or_else(|_| "Serialization error".to_string())
}

#[rustler::nif]
pub fn parse_to_graph(lang_name: String, code: String) -> String {
    parse_to_graph_impl(lang_name, code)
}

fn flatten_node(node: Node, source: &str, nodes: &mut Vec<Value>, edges: &mut Vec<Value>) -> u64 {
    let node_id = node.id() as u64;
    let kind = node.kind();
    
    let is_dependency = matches!(
        kind,
        "import_statement" | "import_from_statement" | "export_statement" | "lexical_declaration"
    );

    nodes.push(json!({
        "id": node_id,
        "type": kind,
        "start_byte": node.start_byte(),
        "end_byte": node.end_byte(),
        "text": &source[node.start_byte()..node.end_byte()],
        "is_dependency": is_dependency
    }));

    let mut cursor = node.walk();
    if cursor.goto_first_child() {
        loop {
            let child_node = cursor.node();
            let child_id = flatten_node(child_node, source, nodes, edges);
            
            edges.push(json!({
                "from": node_id,
                "to": child_id,
                "type": "CHILD"
            }));

            if !cursor.goto_next_sibling() {
                break;
            }
        }
    }

    node_id
}

pub fn parse_code_impl(lang_name: String, code: String) -> String {
    let language = match lang_name.as_str() {
        "javascript" => tree_sitter_javascript::language(),
        "python" => tree_sitter_python::language(),
        "c" => tree_sitter_c::language(),
        _ => return "Unsupported language".to_string(),
    };

    let mut parser = Parser::new();
    parser.set_language(language).expect("Error loading language");

    let tree = parser.parse(&code, None).unwrap();
    let root_node = tree.root_node();

    let graph_data = serialize_node(root_node, &code);
    serde_json::to_string(&graph_data).unwrap_or_else(|_| "Serialization error".to_string())
}

#[rustler::nif]
pub fn parse_code(lang_name: String, code: String) -> String {
    parse_code_impl(lang_name, code)
}

fn serialize_node(node: Node, source: &str) -> Value {
    let mut children = Vec::new();
    let mut cursor = node.walk();
    
    if cursor.goto_first_child() {
        loop {
            children.push(serialize_node(cursor.node(), source));
            if !cursor.goto_next_sibling() {
                break;
            }
        }
    }

    json!({
        "type": node.kind(),
        "start_byte": node.start_byte(),
        "end_byte": node.end_byte(),
        "text": &source[node.start_byte()..node.end_byte()],
        "children": children
    })
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn ingest_to_memgraph(lang_name: String, code: String) -> NifResult<(rustler::Atom, String)> {
    RUNTIME.block_on(async {
        let mut client_lock = CLIENT.lock().await;
        
        if client_lock.is_none() {
            match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
                Ok(c) => *client_lock = Some(Arc::new(c)),
                Err(e) => return Ok((atoms::error(), format!("Connection Error: {}", e))),
            }
        }

        let client = client_lock.as_ref().unwrap().clone();
        
        let language = match lang_name.as_str() {
            "javascript" => tree_sitter_javascript::language(),
            "python" => tree_sitter_python::language(),
            "c" => tree_sitter_c::language(),
            _ => return Ok((atoms::error(), "Unsupported language".to_string())),
        };

        let mut parser = Parser::new();
        parser.set_language(language).expect("Error loading language");

        let tree = parser.parse(&code, None).unwrap();
        let root_node = tree.root_node();

        // Start a transaction for the entire ingestion
        let mut txn = match client.graph.start_txn().await {
            Ok(t) => t,
            Err(e) => return Ok((atoms::error(), format!("Transaction Error: {}", e))),
        };

        let mut node_count = 0;
        if let Err(e) = ingest_node(&mut txn, root_node, &code, &mut node_count).await {
            let _ = txn.rollback().await;
            return Ok((atoms::error(), format!("Ingestion Error: {}", e)));
        }

        match txn.commit().await {
            Ok(_) => Ok((atoms::ok(), format!("Ingested {} nodes", node_count))),
            Err(e) => Ok((atoms::error(), format!("Commit Error: {}", e))),
        }
    })
}

async fn ingest_node(txn: &mut Txn, node: Node<'_>, source: &str, count: &mut u32) -> Result<(), Error> {
    let node_id = node.id() as u64;
    let kind = node.kind();
    let text = &source[node.start_byte()..node.end_byte()];
    let escaped_text = text.replace("'", "\\'"); // Basic escaping for Cypher

    let create_query = format!(
        "MERGE (n:ASTNode {{id: {}}}) SET n.type = '{}', n.text = '{}'",
        node_id, kind, escaped_text
    );
    
    txn.run(query(&create_query)).await?;
    *count += 1;

    let mut cursor = node.walk();
    if cursor.goto_first_child() {
        loop {
            let child_node = cursor.node();
            let child_id = child_node.id() as u64;
            
            // Recurse
            Box::pin(ingest_node(txn, child_node, source, count)).await?;
            
            // Create edge
            let edge_query = format!(
                "MATCH (parent:ASTNode {{id: {}}}), (child:ASTNode {{id: {}}}) MERGE (parent)-[:CHILD]->(child)",
                node_id, child_id
            );
            txn.run(query(&edge_query)).await?;

            if !cursor.goto_next_sibling() {
                break;
            }
        }
    }

    Ok(())
}

rustler::init!("Elixir.Sensory.Native", [parse_code, parse_to_graph, ingest_to_memgraph]);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_code_javascript() {
        let code = "const x = 10;".to_string();
        let result = parse_code_impl("javascript".to_string(), code);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["type"], "program");
    }

    #[test]
    fn test_parse_to_graph_javascript() {
        let code = "const x = 10;".to_string();
        let result = parse_to_graph_impl("javascript".to_string(), code);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert!(v["nodes"].as_array().unwrap().len() > 0);
    }

    #[test]
    fn test_unsupported_language() {
        let result = parse_code_impl("cobol".to_string(), "MOVE 1 TO X".to_string());
        assert_eq!(result, "Unsupported language");
    }
}
