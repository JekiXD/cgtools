use minwebgpu as gl;

use lazy_static::lazy_static;

lazy_static! {
  static ref FRAGMENT_2D_MAIN : String = {
    String::from( include_str!( "../shaders/fragment_2d_main.wgsl" ) )
  };
}

const VERTEX_MAIN : &'static str = include_str!( "../shaders/vertex_main.wgsl" );

pub struct ShaderAssembler
{
  pub fragment : String,
  pub hash : String,
  pub noise : String,
  pub fin : String
}

impl ShaderAssembler 
{
  pub fn new( hash : &str, noise : &str ) -> Self
  {
    Self
    {
      hash : hash.to_string(),
      noise : noise.to_string(),
      fragment : FRAGMENT_2D_MAIN,
      fin : String::new()
    }
  }

  pub fn assemble( &mut self )
  {
    self.fin.clear();
    self.fin.push_str( &self.fragment );
    self.fin.push_str( &self.noise );
    self.fin.push_str( &self.hash );
  }
}