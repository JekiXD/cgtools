use minwebgpu as gl;

#[ repr( C ) ]
#[ derive( Clone, Copy, Default, gl::mem::Pod, gl::mem::Zeroable ) ]
pub struct UniformsRaw
{
  pub resolution : [ f32; 2 ],
  pub linear_hash : i32,
  pub _padding : [ f32; 1 ]
}

#[ derive( Default ) ]
pub struct Uniforms
{
  pub resolution : gl::F32x2,
  pub linear_hash : i32,
}

impl Uniforms 
{
  pub fn as_raw( &self ) -> UniformsRaw
  {
    UniformsRaw
    {
      resolution : self.resolution.to_array(),
      linear_hash : self.linear_hash,
      ..Default::default()
    }
  }
}

pub struct UniformsState
{
  pub uniforms : Uniforms,
  pub buffer : gl::web_sys::GpuBuffer,
  pub bind_group_layout : gl::web_sys::GpuBindGroupLayout,
  pub bind_group : gl::web_sys::GpuBindGroup
}

impl UniformsState
{
  pub fn new( device : &gl::web_sys::GpuDevice ) -> Result< Self, gl::WebGPUError >
  {
    let buffer = gl::BufferDescriptor::new( gl::BufferUsage::UNIFORM | gl::BufferUsage::COPY_DST )
    .size::< UniformsRaw >()
    .create( device )?;

    let bind_group_layout = gl::BindGroupLayoutDescriptor::new()
    .fragment()
    .entry_from_ty( gl::binding_type::buffer().uniform() )
    .create( device )?;

    let bind_group = gl::BindGroupDescriptor::new( &bind_group_layout )
    .auto_bindings()
    .entry_from_resource( &gl::BufferBinding::new( &buffer ) )
    .create( device );

    let result = UniformsState
    {
      uniforms : Uniforms::default(),
      buffer,
      bind_group_layout,
      bind_group
    };

    Ok( result )
  }

  pub fn update( &mut self, queue : &gl::web_sys::GpuQueue ) -> Result< (), gl::WebGPUError >
  {
    gl::queue::write_buffer( queue, &self.buffer, &[ self.uniforms.as_raw() ] )?;

    Ok( () )
  }
}