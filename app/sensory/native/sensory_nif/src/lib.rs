use rustler::{Env, Term, NifResult};
use tree_sitter::{Parser, Language, Node};
use serde_json::{json, Value};

extern "C" { 
    fn tree_sitter_javascript() -> Language; 
    fn tree_sitter_python() -> Language;
    fn tree_sitter_c() -> Language;
}

#[rustler::nif]
pub fn parse_code(lang_name: String, code: String) -> String {
    let language = match lang_name.as_str() {
        "javascript" => unsafe { tree_sitter_javascript() },
        "python" => unsafe { tree_sitter_python() },
        "c" => unsafe { tree_sitter_c() },
        _ => return "Unsupported language".to_string(),
    };

    let mut parser = Parser::new();
    parser.set_language(language).expect("Error loading language");

    let tree = parser.parse(&code, None).unwrap();
    let root_node = tree.root_node();

    let graph_data = serialize_node(root_node, &code);
    serde_json::to_string(&graph_data).unwrap_or_else(|_| "Serialization error".to_string())
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

rustler::init!("Elixir.Sensory.Native", [parse_code]);
