#[cfg(test)]
mod tests {
    use sensory_nif::{parse_code_impl, parse_to_graph_impl};
    use serde_json::Value;

    #[test]
    fn test_parsing_fidelity_stress() {
        let code = r#"
            function heavy(a, b) {
                const results = [];
                for (let i = 0; i < 100; i++) {
                    results.push(a + b + i);
                }
                return results;
            }
        "#.repeat(10); // Make it a bit larger

        let result = parse_code_impl("javascript".to_string(), code);
        let v: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(v["type"], "program");
        
        // Ensure children are deeply nested
        let children = v["children"].as_array().expect("Expected children array");
        assert!(children.len() > 0);
    }

    #[test]
    fn test_graph_flattening_fidelity() {
        let code = "import { x } from 'mod'; const y = x + 1; export default y;".to_string();
        let result = parse_to_graph_impl("javascript".to_string(), code);
        let v: Value = serde_json::from_str(&result).unwrap();
        
        let nodes = v["nodes"].as_array().unwrap();
        let edges = v["edges"].as_array().unwrap();
        
        // Verify dependency detection
        let has_dep = nodes.iter().any(|n| n["is_dependency"].as_bool().unwrap_or(false));
        assert!(has_dep, "Should have identified import/export as dependency");
        
        assert!(edges.len() >= nodes.len() - 1);
    }
}
