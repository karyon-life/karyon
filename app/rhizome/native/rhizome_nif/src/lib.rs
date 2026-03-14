mod resource;
mod memgraph;
mod xtdb;
mod optimizer;

use rustler::{Env, Term};
use crate::resource::GraphResource;

rustler::init!(
    "Elixir.Rhizome.Native",
    [
        resource::create_pointer,
        resource::get_pointer_id,
        memgraph::memgraph_query,
        xtdb::xtdb_submit,
        optimizer::optimize_graph,
        memgraph::weaken_edge,
    ],
    load = load
);

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(GraphResource, env);
    true
}
