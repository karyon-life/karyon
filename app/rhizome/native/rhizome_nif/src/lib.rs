pub mod resource;
pub mod client;
pub mod memgraph;
pub mod xtdb;
pub mod optimizer;

use rustler::{Env, Term};
use crate::resource::GraphResource;

rustler::init!("Elixir.Rhizome.Native", load = load);

fn load(env: Env, _info: Term) -> bool {
    // Register the GraphResource for use with ResourceArc
    let _ = rustler::resource!(GraphResource, env);
    true
}
