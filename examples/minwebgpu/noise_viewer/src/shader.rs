use minwebgpu as gl;

pub struct Components
{
  pub hash : String,
  pub noise : String,
}

impl Components 
{
  pub async fn load_hash( &mut self, name : &str )
  {
    let res = gl::file::load( &format!( "shaders/hash/{}", name ) ).await.expect( "Failed to fetch hash shader" );
    self.hash = String::from_utf8( res ).expect( "Failed to convert hash to string" );
  }  

  pub async fn load_noise( &mut self, name : &str )
  {
    let res = gl::file::load( &format!( "shaders/noise/{}", name ) ).await.expect( "Failed to fetch noise shader" );
    self.noise = String::from_utf8( res ).expect( "Failed to convert noise to string" );
  }   
}