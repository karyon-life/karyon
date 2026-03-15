use rhizome_nif::client::MemgraphClient;
use std::sync::Arc;
use tokio::runtime::Runtime;

#[test]
fn test_memgraph_concurrent_ingestion() {
    let rt = Runtime::new().unwrap();
    rt.block_on(async {
        // We use a mock or assumes a local Memgraph is running
        let client = match MemgraphClient::new("bolt://127.0.0.1:7687", "memgraph", "").await {
            Ok(c) => Arc::new(c),
            Err(_) => {
                println!("Skipping Memgraph pressure test: Memgraph not reachable");
                return;
            }
        };

        let mut handles = vec![];
        for i in 0..64 {
            let c = client.clone();
            handles.push(tokio::spawn(async move {
                let query = format!("CREATE (n:PressureNode {{id: {}, val: rand()}})", i);
                c.execute_query(&query).await
            }));
        }

        for handle in handles {
            handle.await.unwrap().expect("Concurrent query failed");
        }
        
        // Cleanup
        client.execute_query("MATCH (n:PressureNode) DELETE n").await.unwrap();
    });
}
