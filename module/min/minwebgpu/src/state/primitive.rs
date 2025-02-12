/// Internal namespace.
mod private
{
  use crate::*;

  #[ derive( Default, Clone ) ]
  pub struct PrimitiveState
  {
    /// Defaults to `None`
    cull_mode : Option< GpuCullMode >,
    /// Default to `CCW`
    front_face : Option< GpuFrontFace >,
    /// Defaults to `TriangleList `
    topology : Option< GpuPrimitiveTopology >,
    /// Should be specified for strip primitive topology
    strip_index_format : Option< GpuIndexFormat >,
    /// If omitted, defaults to false.
    unclipped_depth : Option< bool >
  }

  impl  PrimitiveState 
  {
    pub fn new() -> Self
    {
      Self::default()
    }

    pub fn cull_none( mut self ) -> Self
    {
      self.cull_mode = Some( GpuCullMode::None );
      self
    }

    pub fn cull_front( mut self ) -> Self
    {
      self.cull_mode = Some( GpuCullMode::Front );
      self
    }

    pub fn cull_back( mut self ) -> Self
    {
      self.cull_mode = Some( GpuCullMode::Back );
      self
    }

    pub fn cw( mut self ) -> Self
    {
      self.front_face = Some( GpuFrontFace::Cw );
      self
    }

    pub fn unclipped_depth( mut self ) -> Self
    {
      self.unclipped_depth = Some( true );
      self
    }

    pub fn topology( mut self, topology : GpuPrimitiveTopology ) -> Self
    {
      self.topology = Some( topology );
      self
    }

    pub fn points( mut self ) -> Self
    {
      self.topology = Some( GpuPrimitiveTopology::PointList );
      self
    }

    pub fn lines( mut self ) -> Self
    {
      self.topology = Some( GpuPrimitiveTopology::LineList );
      self
    }

    pub fn triangles( mut self ) -> Self
    {
      self.topology = Some( GpuPrimitiveTopology::TriangleList );
      self
    }

    pub fn line_strip( mut self ) -> Self
    {
      self.topology = Some( GpuPrimitiveTopology::LineStrip );
      self
    }

    pub fn triangle_strip( mut self ) -> Self
    {
      self.topology = Some( GpuPrimitiveTopology::TriangleStrip );
      self
    }
  }

  impl From< PrimitiveState > for web_sys::GpuPrimitiveState
  {
    fn from( value: PrimitiveState ) -> Self 
    {
      let state = web_sys::GpuPrimitiveState::new();

      if let Some( v ) = value.cull_mode { state.set_cull_mode( v ); }
      if let Some( v ) = value.front_face { state.set_front_face( v ); }
      if let Some( v ) = value.topology { state.set_topology( v ); }
      if let Some( v ) = value.strip_index_format { state.set_strip_index_format( v ); }
      if let Some( v ) = value.unclipped_depth { state.set_unclipped_depth( v ); }

      state
    }
  }
}

crate::mod_interface!
{

  exposed use
  {
    PrimitiveState
  };

}
