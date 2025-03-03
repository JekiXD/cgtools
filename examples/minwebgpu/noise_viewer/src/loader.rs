use minwebgpu as gl;


pub struct Loader;

impl Loader 
{
  pub async fn load_file( file : &str ) -> Result< String, gl::JsValue >
  {
    let opts = gl::web_sys::RequestInit::new();
    opts.set_method( "GET" );
    opts.set_mode( gl::web_sys::RequestMode::Cors );

    let window = gl::web_sys::window().unwrap();
    let origin = window.location().origin().unwrap();
    let url = format!( "{}/{}", origin, file );

    let request = gl::web_sys::Request::new_with_str_and_init( &url, &opts ).expect( "Invalid url" );

    let resp_value = gl::JsFuture::from( window.fetch_with_request( &request ) ).await.expect( "Fetch request fail" );
    let resp : gl::web_sys::Response = resp_value.dyn_into()?;

    let array_buffer_promise = resp.array_buffer()?;
    let array_buffer = gl::JsFuture::from( array_buffer_promise ).await?;

    let uint8_array = gl::js_sys::Uint8Array::new( &array_buffer );
    let mut data = vec![ 0; uint8_array.length() as usize ];
    uint8_array.copy_to( &mut data[ .. ] );

    Ok( String::from_utf8( data ).unwrap() )
  }

  pub async fn load_hash( name : &str ) -> Result< String, gl::JsValue >
  {
    Self::load_file( &format!( "shaders/hash/{}.wgsl", name ) ).await
  }

  pub async fn load_noise_2d( name : &str ) -> Result< String, gl::JsValue >
  {
    Self::load_file( &format!( "shaders/noise/2d/{}.wgsl", name ) ).await
  }
}