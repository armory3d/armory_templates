import bpy
import arm.api
import arm.material.mat_state as mat_state
import arm.material.cycles as cycles
import arm.material.make_mesh as make_mesh
import arm.assets as assets
import arm.utils

def register():
    arm.api.add_driver('Celshade', draw_props, make_rpass, make_rpath)

def draw_props(layout):
    rpdat = arm.utils.get_rp()

    layout.label('Renderer')
    box = layout.box().column()
    row = box.row()
    box.prop(rpdat, 'arm_samples_per_pixel')
    box.prop(rpdat, 'arm_texture_filter')
    box.prop(rpdat, 'arm_skin')
    row = box.row()
    row.enabled = rpdat.arm_skin.startswith('GPU')
    row.prop(rpdat, 'arm_skin_max_bones_auto')
    row = box.row()
    row.enabled = not rpdat.arm_skin_max_bones_auto
    row.prop(rpdat, 'arm_skin_max_bones')
    row = box.row()
    row.prop(rpdat, "rp_hdr")
    row.prop(rpdat, "rp_stereo")
    row = box.row()
    row.prop(rpdat, 'arm_rp_displacement')
    row.prop(rpdat, 'arm_culling')

    layout.label('Shadows')
    box = layout.box().column()
    box.prop(rpdat, 'rp_shadowmap')
    col = box.column()
    col.enabled = rpdat.rp_shadowmap != 'Off'
    col.prop(rpdat, 'rp_shadowmap_cascades')
    col2 = col.column()
    col2.enabled = rpdat.rp_shadowmap_cascades != '1'
    col2.prop(rpdat, 'arm_shadowmap_split')
    col.prop(rpdat, 'arm_pcfsize')

    layout.label('World')
    box = layout.box().column()
    row = box.row()
    row.prop(rpdat, "rp_background", expand=True)
    row = box.row()
    row.prop(rpdat, 'arm_irradiance')
    col = row.column()
    col.enabled = rpdat.arm_irradiance
    col.prop(rpdat, 'arm_radiance')
    row = box.row()
    row.enabled = rpdat.arm_irradiance
    col = row.column()
    col.prop(rpdat, 'arm_radiance_sky')
    colb = row.column()
    colb.enabled = rpdat.arm_radiance
    colb.prop(rpdat, 'arm_radiance_size')
    box.prop(rpdat, 'arm_clouds')
    col = box.column()
    col.enabled = rpdat.arm_clouds
    row = col.row(align=True)
    row.alignment = 'EXPAND'
    row.prop(rpdat, 'arm_clouds_density')
    row.prop(rpdat, 'arm_clouds_size')
    row = col.row(align=True)
    row.alignment = 'EXPAND'
    row.prop(rpdat, 'arm_clouds_lower')
    row.prop(rpdat, 'arm_clouds_upper')
    row = col.row(align=True)
    row.alignment = 'EXPAND'
    row.prop(rpdat, 'arm_clouds_precipitation')
    row.prop(rpdat, 'arm_clouds_eccentricity')
    col.prop(rpdat, 'arm_clouds_secondary')
    row = col.row()
    row.prop(rpdat, 'arm_clouds_wind')
    
    layout.separator()
    layout.prop(rpdat, "rp_render_to_texture")
    box = layout.box().column()
    box.enabled = rpdat.rp_render_to_texture
    row = box.row()
    row.prop(rpdat, "rp_antialiasing", expand=True)
    box.prop(rpdat, "rp_supersampling")
    box.prop(rpdat, 'arm_rp_resolution')
    if rpdat.arm_rp_resolution == 'Custom':
        box.prop(rpdat, 'arm_rp_resolution_size')
        box.prop(rpdat, 'arm_rp_resolution_filter')
    box.separator()
    box.prop(rpdat, "rp_bloom")
    col = box.column()
    col.enabled = rpdat.rp_bloom
    row = col.row(align=True)
    row.alignment = 'EXPAND'
    row.prop(rpdat, 'arm_bloom_threshold')
    row.prop(rpdat, 'arm_bloom_strength')
    col.prop(rpdat, 'arm_bloom_radius')
    box.separator()
    box.prop(rpdat, "rp_volumetriclight")
    row = box.row(align=True)
    row.alignment = 'EXPAND'
    row.enabled = rpdat.rp_volumetriclight
    row.prop(rpdat, 'arm_volumetric_light_air_color', text="")
    row.prop(rpdat, 'arm_volumetric_light_air_turbidity', text="Turbidity")
    row.prop(rpdat, 'arm_volumetric_light_steps', text="Steps")

    layout.prop(rpdat, "rp_compositornodes")
    box = layout.box().column()
    box.enabled = rpdat.rp_compositornodes
    box.prop(rpdat, 'arm_tonemap')
    box.prop(rpdat, 'arm_letterbox')
    col = box.column()
    col.enabled = rpdat.arm_letterbox
    col.prop(rpdat, 'arm_letterbox_size')
    box.prop(rpdat, 'arm_sharpen')
    col = box.column()
    col.enabled = rpdat.arm_sharpen
    col.prop(rpdat, 'arm_sharpen_strength')
    box.prop(rpdat, 'arm_fisheye')
    box.prop(rpdat, 'arm_vignette')
    box.prop(rpdat, 'arm_lensflare')
    box.prop(rpdat, 'arm_grain')
    col = box.column()
    col.enabled = rpdat.arm_grain
    col.prop(rpdat, 'arm_grain_strength')
    box.prop(rpdat, 'arm_fog')
    col = box.column()
    col.enabled = rpdat.arm_fog
    row = col.row(align=True)
    row.alignment = 'EXPAND'
    row.prop(rpdat, 'arm_fog_color', text="")
    row.prop(rpdat, 'arm_fog_amounta', text="A")
    row.prop(rpdat, 'arm_fog_amountb', text="B")
    box.separator()
    box.prop(rpdat, "rp_autoexposure")
    col = box.column()
    col.enabled = rpdat.rp_autoexposure
    col.prop(rpdat, 'arm_autoexposure_strength', text='Strength')
    box.prop(rpdat, 'arm_lens_texture')
    box.prop(rpdat, 'arm_lut_texture')

def make_rpass(rpass):
    if rpass == 'mesh':
        return make_mesh_pass(rpass)
    return None

def make_mesh_pass(rpass):
    con = { 'name': rpass, 'depth_write': True, 'compare_mode': 'less', 'cull_mode': 'clockwise' }
    
    con_mesh = mat_state.data.add_context(con)
    mat_state.con_mesh = con_mesh

    wrd = bpy.data.worlds['Arm']
    vert = con_mesh.make_vert()
    frag = con_mesh.make_frag()
    geom = None
    tesc = None
    tese = None

    vert.add_uniform('mat3 N', '_normalMatrix')
    vert.write_attrib('vec4 spos = vec4(pos, 1.0);')
    frag.ins = vert.outs

    frag.add_include('compiled.glsl')
    frag.add_uniform('vec3 lightDir', '_lightDirection')
    frag.add_uniform('vec3 lightColor', '_lightColor')
    frag.add_uniform('float envmapStrength', link='_envmapStrength')

    frag.write('float visibility = 1.0;')
    frag.write('float dotNL = max(dot(n, lightDir), 0.0);')

    is_shadows = not '_NoShadows' in wrd.world_defs

    if is_shadows:
        vert.add_out('vec4 lightPos')
        vert.add_uniform('mat4 LWVP', '_biasLightWorldViewProjectionMatrix')
        vert.write('lightPos = LWVP * spos;')
        frag.add_include('std/shadows.glsl')
        frag.add_uniform('sampler2D shadowMap')
        frag.add_uniform('float shadowsBias', '_lightShadowsBias')
        frag.add_uniform('bool receiveShadow')
        frag.write('    if (receiveShadow && lightPos.w > 0.0) {')
        frag.write('    vec3 lPos = lightPos.xyz / lightPos.w;')

        frag.write('    const vec2 smSize = shadowmapSize;')
        frag.write('    visibility *= PCF(shadowMap, lPos.xy, lPos.z - shadowsBias, smSize);')

        # frag.write('    const float texelSize = 1.0 / shadowmapSize.x;')
        # frag.write('    visibility = 0.0;')
        # frag.write('    visibility += float(texture(shadowMap, lPos.xy).r + shadowsBias > lPos.z);')
        # frag.write('    visibility += float(texture(shadowMap, lPos.xy + vec2(texelSize, 0.0)).r + shadowsBias > lPos.z) * 0.5;')
        # frag.write('    visibility += float(texture(shadowMap, lPos.xy + vec2(-texelSize, 0.0)).r + shadowsBias > lPos.z) * 0.25;')
        # frag.write('    visibility += float(texture(shadowMap, lPos.xy + vec2(0.0, texelSize)).r + shadowsBias > lPos.z) * 0.5;')
        # frag.write('    visibility += float(texture(shadowMap, lPos.xy + vec2(0.0, -texelSize)).r + shadowsBias > lPos.z) * 0.25;')
        # frag.write('    visibility /= 2.5;')
        frag.write('    }')

    frag.write('vec3 basecol;')
    frag.write('float roughness;')
    frag.write('float metallic;')
    frag.write('float occlusion;')
    frag.write('float specular;')
    arm_discard = mat_state.material.arm_discard
    if arm_discard:
        frag.write('float opacity;')
    cycles.parse(mat_state.nodes, con_mesh, vert, frag, geom, tesc, tese, parse_opacity=arm_discard, parse_displacement=False)

    make_mesh.write_vertpos(vert)

    if arm_discard:
        opac = mat_state.material.arm_discard_opacity
        frag.write('if (opacity < {0}) discard;'.format(opac))

    if con_mesh.is_elem('tex'):
        vert.add_out('vec2 texCoord')
        vert.write('texCoord = tex;')

    if con_mesh.is_elem('col'):
        vert.add_out('vec3 vcolor')
        vert.write('vcolor = col;')

    if con_mesh.is_elem('tang'):
        vert.add_out('mat3 TBN')
        make_mesh.write_norpos(con_mesh, vert, declare=True)
        vert.write('vec3 tangent = normalize(N * tang);')
        vert.write('vec3 bitangent = normalize(cross(wnormal, tangent));')
        vert.write('TBN = mat3(tangent, bitangent, wnormal);')
    else:
        vert.add_out('vec3 wnormal')
        make_mesh.write_norpos(con_mesh, vert)
        frag.write_attrib('vec3 n = normalize(wnormal);')

    frag.add_out('vec4 fragColor')
    frag.write('vec3 direct = basecol * step(0.5, dotNL) * visibility * lightColor;')
    frag.write('vec3 indirect = basecol * envmapStrength;')
    frag.write('fragColor = vec4(direct + indirect, 1.0);')

    if '_LDR' in wrd.world_defs:
        frag.write('fragColor.rgb = pow(fragColor.rgb, vec3(1.0 / 2.2));')

    assets.vs_equal(con_mesh, assets.shader_cons['mesh_vert'])

    make_mesh.make_finalize(con_mesh)

    return con_mesh

def make_rpath():
    assets_path = arm.utils.get_sdk_path() + 'armory/Assets/'
    wrd = bpy.data.worlds['Arm']
    rpdat = arm.utils.get_rp()

    if rpdat.rp_hdr:
        assets.add_khafile_def('rp_hdr')
    else:
        wrd.world_defs += '_LDR'

    if rpdat.rp_shadowmap != 'Off':
        assets.add_khafile_def('rp_shadowmap')
        assets.add_khafile_def('rp_shadowmap_size={0}'.format(rpdat.rp_shadowmap))

    assets.add_khafile_def('rp_background={0}'.format(rpdat.rp_background))
    if rpdat.rp_background == 'World':
        assets.add_shader_pass('world_pass')
        if '_EnvClouds' in wrd.world_defs:
            assets.add(assets_path + 'noise256.png')
            assets.add_embedded_data('noise256.png')

    if rpdat.rp_render_to_texture:
        assets.add_khafile_def('rp_render_to_texture')

        if rpdat.rp_compositornodes:
            assets.add_khafile_def('rp_compositornodes')
            compo_depth = False
            if rpdat.arm_tonemap != 'Off':
                wrd.compo_defs = '_CTone' + rpdat.arm_tonemap
            if rpdat.rp_antialiasing == 'FXAA':
                wrd.compo_defs += '_CFXAA'
            if rpdat.arm_letterbox:
                wrd.compo_defs += '_CLetterbox'
            if rpdat.arm_grain:
                wrd.compo_defs += '_CGrain'
            if bpy.data.scenes[0].cycles.film_exposure != 1.0:
                wrd.compo_defs += '_CExposure'
            if rpdat.arm_fog:
                wrd.compo_defs += '_CFog'
                compo_depth = True
            if len(bpy.data.cameras) > 0 and bpy.data.cameras[0].dof_distance > 0.0:
                wrd.compo_defs += '_CDOF'
                compo_depth = True
            if compo_depth:
                wrd.compo_defs += '_CDepth'
                assets.add_khafile_def('rp_compositordepth')
            if rpdat.arm_lens_texture != '':
                wrd.compo_defs += '_CLensTex'
                assets.add_embedded_data('lenstexture.jpg')
            if rpdat.arm_fisheye:
                wrd.compo_defs += '_CFishEye'
            if rpdat.arm_vignette:
                wrd.compo_defs += '_CVignette'
            if rpdat.arm_lensflare:
                wrd.compo_defs += '_CGlare'
            if rpdat.arm_lut_texture != '':
                wrd.compo_defs += '_CLUT'
                assets.add_embedded_data('luttexture.jpg')
            if '_CDOF' in wrd.compo_defs or '_CFXAA' in wrd.compo_defs or '_CSharpen' in wrd.compo_defs:
                wrd.compo_defs += '_CTexStep'
            if '_CDOF' in wrd.compo_defs or '_CFog' in wrd.compo_defs or '_CGlare' in wrd.compo_defs:
                wrd.compo_defs += '_CCameraProj'
            assets.add_shader_pass('compositor_pass')
        else:
            assets.add_shader_pass('copy_pass')

        assets.add_khafile_def('rp_antialiasing={0}'.format(rpdat.rp_antialiasing))

        if rpdat.rp_antialiasing == 'SMAA' or rpdat.rp_antialiasing == 'TAA':
            assets.add_shader_pass('smaa_edge_detect')
            assets.add_shader_pass('smaa_blend_weight')
            assets.add_shader_pass('smaa_neighborhood_blend')
            assets.add(assets_path + 'smaa_area.png')
            assets.add(assets_path + 'smaa_search.png')
            assets.add_embedded_data('smaa_area.png')
            assets.add_embedded_data('smaa_search.png')
            wrd.world_defs += '_SMAA'
            if rpdat.rp_antialiasing == 'TAA':
                assets.add_shader_pass('taa_pass')
                assets.add_shader_pass('copy_pass')

        if rpdat.rp_antialiasing == 'TAA' or rpdat.rp_motionblur == 'Object':
            assets.add_khafile_def('arm_veloc')
            wrd.world_defs += '_Veloc'
            if rpdat.rp_antialiasing == 'TAA':
                assets.add_khafile_def('arm_taa')

        assets.add_khafile_def('rp_supersampling={0}'.format(rpdat.rp_supersampling))        
        if rpdat.rp_supersampling == '4':
            assets.add_shader_pass('supersample_resolve')

        if rpdat.rp_volumetriclight:
            assets.add_khafile_def('rp_volumetriclight')
            assets.add_shader_pass('volumetric_light_quad')
            assets.add_shader_pass('volumetric_light')
            assets.add_shader_pass('blur_bilat_pass')

        if rpdat.rp_bloom:
            assets.add_khafile_def('rp_bloom')
            assets.add_shader_pass('bloom_pass')
            assets.add_shader_pass('blur_gaus_pass')

        if rpdat.arm_rp_resolution == 'Custom':
            assets.add_khafile_def('rp_resolution_filter={0}'.format(rpdat.arm_rp_resolution_filter))
