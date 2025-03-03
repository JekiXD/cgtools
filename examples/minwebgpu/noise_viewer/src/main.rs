//! Just draw a large point in the middle of the screen.

use std::{cell::RefCell, rc::Rc};
use serde::{Serialize, Deserialize};
use lazy_static::lazy_static;

use minwebgpu::{self as gl, JsCast, JsValue};
use gl::web_sys::wasm_bindgen::prelude::Closure;
use renderer::Renderer;

mod renderer;
mod uniform;
mod lil_gui;
mod assembler;
mod loader;

const NOISE_LIST : &'static[ &'static str ] = 
&[
  "perlin_21",
  "perlin1_21",
  "perlin2_21",
  "perlin3_21",
];

const HASH_LIST : &'static[ &'static str ] =
&[
  "fasthash"
];

#[ derive( Default, Debug, Serialize, Deserialize ) ]
pub struct GUISettings
{
  hash : String,
  noise : String
}


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
 
  let gui = lil_gui::new_gui();


  let mut settings =  GUISettings::default();
  settings.hash = HASH_LIST[ 0 ].to_string();
  settings.noise = NOISE_LIST[ 0 ].to_string();

  let mut shader_components = ShaderComponents::default();
  shader_components.load_hash( &settings.hash ).await;
  shader_components.load_noise( &settings.noise ).await;
  let settings = serde_wasm_bindgen::to_value( &settings ).expect( "Failed to serialize settings" );

  let renderer = Rc::new( RefCell::new( Renderer::new( &device, &document, presentation_format, shader_components )? ) );

  let noise_dropdown = lil_gui::add_dropdown( &gui, &settings, "noise", NOISE_LIST.clone() );
  let hash_dropdown = lil_gui::add_dropdown( &gui, &settings, "hash", HASH_LIST.clone() );


  let on_change_noise : Closure< dyn Fn( _ ) > =  Closure::new
  (
    {
      let renderer = renderer.clone();
      move | v : String |
      {
        let renderer = renderer.clone();
        let _ = gl::future_to_promise
        ( 
          async move
          { 
            renderer.borrow_mut().set_noise( &v ).await;
            Ok( JsValue::from( 1 ) )
          }
        );
      }
    }
  );

  let on_change_hash : Closure< dyn Fn( _ ) > =  Closure::new
  (
    {
      let renderer = renderer.clone();
      move | v : String |
      {
        let renderer = renderer.clone();
        let _ = gl::future_to_promise
        ( 
          async move
          { 
            renderer.borrow_mut().set_hash( &v ).await;
            Ok( JsValue::from( 1 ) )
          }
        );
      }
    }
  );

  lil_gui::on_change_parameter( &noise_dropdown, &on_change_noise.as_ref().unchecked_ref() );
  lil_gui::on_change_parameter( &hash_dropdown, &on_change_hash.as_ref().unchecked_ref() );
  on_change_hash.forget();
  on_change_noise.forget();

  

  let update_and_draw =
  {
    move | t : f64 |
    {
      let width = canvas.width();
      let height = canvas.height();
      if let Ok( mut renderer ) = renderer.try_borrow_mut()
      {
        renderer.set_resolution( [ width as f32, height as f32 ].into() );
        renderer.update( &device, &queue ).unwrap();
        gl::log::info!("Borrowed");
      
      // renderer.borrow_mut().set_resolution( [ width as f32, height as f32 ].into() );
      // renderer.borrow_mut().update( &device, &queue ).unwrap();

      let canvas_texture = gl::context::current_texture( &context ).unwrap();
      let canvas_view = gl::texture::view( &canvas_texture ).unwrap();

      let command_encoder = device.create_command_encoder();
      let render_pass = command_encoder.begin_render_pass
      (
        &gl::render_pass::desc()
        .color_attachment( gl::ColorAttachment::new( &canvas_view ) )
        .into()
      ).unwrap();

      render_pass.set_pipeline( &renderer.render_pipeline );
      render_pass.set_bind_group( 0, Some( &renderer.uniforms_state.bind_group ) );
      render_pass.draw( 3 );
      render_pass.end();

      gl::queue::submit( &queue, command_encoder.finish() );
      }
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
