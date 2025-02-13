use minwebgpu as gl;

use crate::load_file;

#[ derive( Default ) ]
pub enum HashType
{
  #[ default ]
  OneToOne,
  TwoToOne,
  OneToThree
}

#[ derive( Default ) ]
pub struct ShaderComponents
{
  pub hash_type : HashType,
  pub hash : String,
  pub noise : String,
}

impl ShaderComponents 
{
  pub async fn load_hash( &mut self, name : &str )
  {
    let res = load_file( &format!( "shaders/hash/{}.wgsl", name ) ).await.expect( "Failed to fetch hash shader" );
    self.hash = res;
    //self.hash = String::from_utf8( res ).expect( "Failed to convert hash to string" );
  }  

  pub async fn load_noise( &mut self, name : &str )
  {
    let res = load_file( &format!( "shaders/noise/{}.wgsl", name ) ).await.expect( "Failed to fetch noise shader" );
    self.noise = res;
    //self.noise = String::from_utf8( res ).expect( "Failed to convert noise to string" );
  }   
}