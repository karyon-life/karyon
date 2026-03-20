use rustler::{Binary, NifResult};
use zmq::Context;

lazy_static::lazy_static! {
    static ref ZMQ_CONTEXT: Context = Context::new();
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn zmq_publish_tensor(topic: String, payload: Binary) -> NifResult<(rustler::Atom, String)> {
    let socket = match ZMQ_CONTEXT.socket(zmq::PUB) {
        Ok(socket) => socket,
        Err(error) => return Ok((atoms::error(), format!("ZMQ Socket Error: {}", error))),
    };

    if let Err(error) = socket.connect("tcp://127.0.0.1:5556") {
        return Ok((atoms::error(), format!("ZMQ Connect Error: {}", error)));
    }

    if let Err(error) = socket.send(&topic, zmq::SNDMORE) {
        return Ok((atoms::error(), format!("ZMQ Send Topic Error: {}", error)));
    }

    if let Err(error) = socket.send(payload.as_slice(), 0) {
        return Ok((atoms::error(), format!("ZMQ Send Payload Error: {}", error)));
    }

    Ok((atoms::ok(), "Tensor published successfully".to_string()))
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn zmq_subscribe_sensory(topic: String) -> NifResult<(rustler::Atom, Vec<u8>)> {
    let socket = match ZMQ_CONTEXT.socket(zmq::SUB) {
        Ok(socket) => socket,
        Err(_) => return Ok((atoms::error(), Vec::new())),
    };

    if socket.connect("tcp://127.0.0.1:5557").is_err() {
        return Ok((atoms::error(), Vec::new()));
    }

    if socket.set_subscribe(topic.as_bytes()).is_err() {
        return Ok((atoms::error(), Vec::new()));
    }

    let _ = socket.set_rcvtimeo(100);

    let _topic_recv = match socket.recv_bytes(0) {
        Ok(bytes) => bytes,
        Err(_) => return Ok((atoms::error(), Vec::new())),
    };

    let payload = match socket.recv_bytes(0) {
        Ok(bytes) => bytes,
        Err(_) => return Ok((atoms::error(), Vec::new())),
    };

    Ok((atoms::ok(), payload))
}

rustler::init!("Elixir.Sensory.Raw");
