defmodule Rhizome.ResourceTest do
  use ExUnit.Case, async: true

  test "create_pointer and get_pointer_id correctly handle ResourceArc" do
    id = 42
    resource = Rhizome.Native.create_pointer(id)
    
    # Verify it's a reference (opaque ResourceArc)
    assert is_reference(resource)
    
    # Verify we can extract the ID back
    assert Rhizome.Native.get_pointer_id(resource) == id
  end
end
