use rustler::{Env, Term, NifResult};
use tree_sitter::{Parser, Language};

extern "C" { fn tree_sitter_javascript() -> Language; }

#[rustler::nif]
pub fn parse_code(lang_name: String, code: String) -> String {
    let language = match lang_name.as_str() {
        "javascript" => unsafe { tree_sitter_javascript() },
        _ => return "Unsupported language".to_string(),
    };

    let mut parser = Parser::new();
    parser.set_language(language).expect("Error loading language");

    let tree = parser.parse(code, None).unwrap();
    let root_node = tree.root_node();

    format!("{:?}", root_node)
}

rustler::init!("Elixir.Sensory.Native", [parse_code]);
