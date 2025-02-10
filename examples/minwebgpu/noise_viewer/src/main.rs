//! Just draw a large point in the middle of the screen.

use minwebgpu::{self as gl, JsCast};

mod app;
mod shader;

pub async fn load_dir( dir : &str ) -> Result< String, gl::JsValue >
{

  let opts = gl::web_sys::RequestInit::new();
  opts.set_method( "GET" );
  opts.set_mode( gl::web_sys::RequestMode::Cors );

  let window = gl::web_sys::window().unwrap();
  let origin = window.location().origin().unwrap();
  let url = format!( "{}/{}", origin, dir );

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


async fn run() -> Result< (), gl::WebGPUError >
{
  gl::browser::setup( Default::default() );
  let canvas = gl::canvas::retrieve_or_make()?;
  let document = gl::web_sys::window().unwrap().document().unwrap();

  let context = gl::context::from_canvas( &canvas )?;
  let adapter = gl::context::request_adapter().await;
  let device = gl::context::request_device( &adapter ).await;
  let queue = device.queue();
  let presentation_format = gl::context::preferred_format();
  gl::context::configure( &device, &context, presentation_format )?;

  // Setup
  // Load noises
  {
    let noise_settings =  document.query_selector( "#noise_settings select" ).unwrap().unwrap();
    let noise_list = load_dir("shaders/noise_list.txt").await.unwrap()
    .lines()
    .map( | l |
    {
      l.to_string()
    })
    .collect::< Vec< String > >();

    for n in noise_list.iter()
    {
      let element = document.create_element( "option" ).unwrap();
      let element : gl::web_sys::HtmlOptionElement = element.dyn_into().unwrap();
      element.set_text_content( Some( &n ) );
      noise_settings.append_child( &element ).unwrap();
    }
  }
  // Load hashes
  {
    let hash_settings =  document.query_selector( "#hash_settings select" ).unwrap().unwrap();
    let hash_list = load_dir("shaders/hash_list.txt").await.unwrap()
    .lines()
    .map( | l |
    {
      l.to_string()
    })
    .collect::< Vec< String > >();

    for h in hash_list.iter()
    {
      let element = document.create_element( "option" ).unwrap();
      let element : gl::web_sys::HtmlOptionElement = element.dyn_into().unwrap();
      element.set_text_content( Some( &h ) );
      hash_settings.append_child( &element ).unwrap();
    }
  }
  //
  
  let vertex_main_shader = gl::ShaderModule::new( include_str!( "../shaders/vertex_main.wgsl" ) ).create( &device );
  let fragment_2d_main_shader = gl::ShaderModule::new( include_str!( "../shaders/fragment_2d_main.wgsl" ) ).create( &device );
  
  let render2d_pipeline = gl::render_pipeline::create
  (
    &device, 
    &gl::render_pipeline::desc( gl::VertexState::new( &vertex_main_shader ) )
    .fragment
    ( 
      gl::FragmentState::new( &fragment_2d_main_shader ) 
      .target
      ( 
        gl::ColorTargetState::new()
        .format( presentation_format ) 
      )
    )
    .into()
  )?;

  let update_and_draw =
  {
    move | t : f64 |
    {
      let canvas_texture = gl::context::current_texture( &context ).unwrap();
      let canvas_view = gl::texture::view( &canvas_texture ).unwrap();

      let command_encoder = device.create_command_encoder();
      let render_pass = command_encoder.begin_render_pass
      (
        &gl::render_pass::desc()
        .color_attachment( gl::ColorAttachment::new( &canvas_view ) )
        .into()
      ).unwrap();

      render_pass.set_pipeline( &render2d_pipeline );
      render_pass.draw( 3 );
      render_pass.end();

      gl::queue::submit( &queue, command_encoder.finish() );
      true
    }
  };

   // Run the render loop
  gl::exec_loop::run( update_and_draw );
  
  Ok(())
}

fn main()
{
  gl::spawn_local( async move { run().await.unwrap() } );
}
