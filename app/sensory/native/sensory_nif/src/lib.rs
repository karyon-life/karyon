use rustler::{NifResult};
use tree_sitter::{Parser, Node};
use serde_json::{json, Value};

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

rustler::init!("Elixir.Sensory.Native", [parse_code, parse_to_graph]);

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
