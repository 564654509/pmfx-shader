#version 450 core
#define GLSL
#define BINDING_POINTS
//msaa_resolve depth_4x ps 0
#ifdef GLES
// precision qualifiers
precision highp float;
precision highp sampler2DArray;
#endif
// texture
#ifdef BINDING_POINTS
#define _tex_binding(sampler_index) layout(binding = sampler_index)
#else
#define _tex_binding(sampler_index)
#endif
#define texture_2d( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2D sampler_name
#define texture_3d( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler3D sampler_name
#define texture_cube( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform samplerCube sampler_name
#define texture_2d_array( sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2DArray sampler_name
#ifdef GLES
#define sample_texture_2dms( sampler_name, x, y, fragment ) texture( sampler_name, vec2(0.0, 0.0) )
#define texture_2dms( type, samples, sampler_name, sampler_index ) uniform sampler2D sampler_name
#else
#define sample_texture_2dms( sampler_name, x, y, fragment ) texelFetch( sampler_name, ivec2( x, y ), fragment )
#define texture_2dms( type, samples, sampler_name, sampler_index ) _tex_binding(sampler_index) uniform sampler2DMS sampler_name
#endif
// sampler
#define sample_texture( sampler_name, V ) texture( sampler_name, V )
#define sample_texture_level( sampler_name, V, l ) textureLod( sampler_name, V, l )
#define sample_texture_grad( sampler_name, V, vddx, vddy ) textureGrad( sampler_name, V, vddx, vddy )
#define sample_texture_array( sampler_name, V, a ) texture( sampler_name, vec3(V, a) )
#define sample_texture_array_level( sampler_name, V, a, l ) textureLod( sampler_name, vec3(V, a), l )
// matrix
#define to_3x3( M4 ) float3x3(M4)
#define from_columns_3x3(A, B, C) (transpose(float3x3(A, B, C)))
#define from_rows_3x3(A, B, C) (float3x3(A, B, C))
#define unpack_vb_instance_mat( mat, r0, r1, r2, r3 ) mat[0] = r0; mat[1] = r1; mat[2] = r2; mat[3] = r3;
#define to_data_matrix(mat) mat
// clip
#define remap_z_clip_space( d ) d // gl clip space is -1 to 1, and this is normalised device coordinate
#define remap_depth( d ) (d = d * 0.5 + 0.5)
#define remap_ndc_ray( r ) float2(r.x, r.y)
#define depth_ps_output gl_FragDepth
// def
#define float4x4 mat4
#define float3x3 mat3
#define float2x2 mat2
#define float4 vec4
#define float3 vec3
#define float2 vec2
#define modf mod
#define frac fract
#define lerp mix
#define mul( A, B ) ((A) * (B))
#define mul_tbn( A, B ) ((B) * (A))
#define saturate( A ) (clamp( A, 0.0, 1.0 ))
#define atan2( A, B ) (atan(A, B))
#define ddx dFdx
#define ddy dFdy
#define _pmfx_unroll
#define chebyshev_normalize( V ) (V.xyz / max( max(abs(V.x), abs(V.y)), abs(V.z) ))
#define max3(v) max(max(v.x, v.y),v.z)
#define max4(v) max(max(max(v.x, v.y),v.z), v.w)
#define PI 3.14159265358979323846264
layout(location = 1) in float4 tex_coord_vs_output;
struct vs_output_textured
{
    float4 position;
    float4 tex_coord;
};
struct ps_output_depth
{
    float depth;
};
layout (binding= 0,std140) uniform per_pass
{
    float4 output_buffer_dimension;
};
texture_2dms( float4, 4, texture_msaa_4, 0 );
void main()
{
    //assign vs_output_textured struct from glsl inputs
    vs_output_textured _input;
    _input.tex_coord = tex_coord_vs_output;
    ps_output_depth _output;
    _output.depth = sample_texture_2dms( texture_msaa_4, _input.tex_coord.x * output_buffer_dimension.x, _input.tex_coord.y * output_buffer_dimension.y, 0 ).r;
    _pmfx_unroll
    for( int i = 1; i < 4; ++i )
    {
        float depth = sample_texture_2dms( texture_msaa_4, _input.tex_coord.x * output_buffer_dimension.x, _input.tex_coord.y * output_buffer_dimension.y, i ).r;
        _output.depth = max( depth, _output.depth );
    }
    _output.depth = 0.0;
    //assign glsl global outputs from structs
    depth_ps_output = _output.depth;
}
