"""Detailed independent 195/55 R15 wheel assemblies; Blender 4.5."""
import bpy
import math
from mathutils import Vector


def build_wheels(root, collection):
    made = []
    def mat(name, color, metallic=0., rough=.4):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        p.inputs['Base Color'].default_value = (*color, 1)
        p.inputs['Metallic'].default_value = metallic
        p.inputs['Roughness'].default_value = rough
        return m
    rubber = mat('W3 vulcanized rubber', (.018, .021, .024), 0, .68)
    nt = rubber.node_tree
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 190
    bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .14; bump.inputs['Distance'].default_value = .0005
    nt.links.new(noise.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Normal'])
    alloy = mat('W3 satin machined alloy', (.48, .51, .55), .86, .23)
    barrel = mat('W3 inner cast alloy', (.15, .17, .19), .78, .36)
    steel = mat('W3 brake friction steel', (.26, .27, .28), .85, .37)
    iron = mat('W3 brake iron', (.045, .052, .058), .55, .57)
    dark = mat('W3 recesses', (.008, .010, .012), .1, .48)
    def mesh(name, verts, faces, material, bevel=0):
        me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
        ob = bpy.data.objects.new(name, me); collection.objects.link(ob); ob.parent=root
        ob.data.materials.append(material); made.append(ob)
        for p in me.polygons: p.use_smooth=True
        if bevel:
            mod=ob.modifiers.new('Machined edge fillets','BEVEL'); mod.width=bevel; mod.segments=3
            mod=ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL')
        return ob
    # Coordinates are local wheel radius and outward distance; all revolve about Y.
    for axle,x in [('front',-1.2325), ('rear',1.2325)]:
        for sign in (-1,1):
            y=sign*(.7145 if axle=='front' else .708)
            prefix='W3 '+axle+(' L ' if sign<0 else ' R ')
            def point(r,t,d): return (x+r*math.cos(t), y+sign*d, .29775+r*math.sin(t))
            def revolve(name, profile, material, segments=160, closed=True):
                verts=[point(r,2*math.pi*i/segments,d) for r,d in profile for i in range(segments)]
                faces=[]; n=len(profile)
                for j in range(n if closed else n-1):
                    k=(j+1)%n
                    for i in range(segments):
                        h=(i+1)%segments; faces.append((j*segments+i,j*segments+h,k*segments+h,k*segments+i))
                return mesh(prefix+name,verts,faces,material)
            # Molded shoulders, nearly flat crown with four genuinely recessed tread channels.
            profile=[(.187,-.075),(.193,-.085),(.222,-.096),(.259,-.0975),(.282,-.088),(.292,-.075)]
            for d in [-.067,-.057,-.053,-.049,-.035,-.020,-.016,-.012,.012,.016,.020,.035,.049,.053,.057,.067]:
                r=.29775-(.004 if abs(abs(d)-.053)<.001 or abs(abs(d)-.016)<.001 else 0)
                profile.append((r,d))
            profile.extend([(.292,.075),(.282,.088),(.259,.0975),(.222,.096),(.193,.085),(.187,.075)])
            revolve('tire 195 55 R15',profile,rubber)
            for d in (-.0958,.0958):
                revolve('sidewall molding',[(.239,d),(.240,d+sign*.0004),(.242,d),(.240,d-.0004)],rubber)
            # Transverse tread sipes are consolidated into a single mesh per wheel.
            vv=[]; ff=[]
            for j in range(76):
                a=j*2*math.pi/76
                for d0,d1 in [(-.075,-.056),(-.047,-.020),(.020,.047),(.056,.075)]:
                    r=.29785 if abs(d0)<.055 else .2945
                    base=len(vv)
                    vv.extend([point(r,a-.002,d0),point(r,a+.002,d0),point(r,a+.029,d1),point(r,a+.025,d1)])
                    ff.append(tuple(base+k for k in range(4)))
            mesh(prefix+'fine shoulder sipes',vv,ff,dark)
            revolve('open rim barrel',[(.180,-.078),(.188,-.078),(.194,-.071),(.194,.072),(.190,.083),(.181,.083),(.177,.071),(.177,-.065)],barrel)
            revolve('polished outer flange',[(.182,.080),(.188,.081),(.193,.085),(.193,.090),(.189,.094),(.182,.094),(.179,.090)],alloy)
            revolve('inner bead flange',[(.185,-.083),(.191,-.083),(.193,-.078),(.185,-.075)],alloy)
            # Thin annular front rotors leave visible hollow space through the spokes.
            if axle=='front':
                revolve('ventilated brake rotor',[(.048,.029),(.129,.029),(.129,.041),(.048,.041)],steel)
                # Dark recessed drilled bores on braking surface, batched as one mesh.
                vv=[]; ff=[]
                for j in range(28):
                    for r,phase in [(.100,0),(.117,.043)]:
                        a=j*2*math.pi/28+phase; cx=r*math.cos(a); cz=r*math.sin(a); base=len(vv)
                        for k in range(10):
                            b=2*math.pi*k/10; vv.append((x+cx+.0023*math.cos(b),y+sign*.04115,.29775+cz+.0023*math.sin(b)))
                        ff.append(tuple(base+k for k in range(10)))
                mesh(prefix+'rotor bore recesses',vv,ff,dark)
            else:
                revolve('rear brake drum',[(0,.003),(.108,.003),(.116,.011),(.116,.038),(.104,.045),(0,.045)],iron)
            revolve('hub',[(0,.050),(.060,.050),(.065,.064),(.063,.083),(.042,.090),(0,.090)],alloy)
            # Ten swept tapered spokes, grouped in five pairs and open between them.
            verts=[]; faces=[]
            for j in range(5):
                a=j*2*math.pi/5+math.pi/2
                for branch in (-1,1):
                    stations=[(.050,a+branch*.12,.012,.082),(.095,a+branch*.17,.010,.086),(.148,a+branch*.145,.009,.087),(.183,a+branch*.13,.010,.088)]
                    base=len(verts)
                    for r,t,w,d in stations:
                        for depth in (d-.017,d):
                            for side in (-1,1):
                                verts.append((x+r*math.cos(t)-side*w*math.sin(t),y+sign*depth,.29775+r*math.sin(t)+side*w*math.cos(t)))
                    for k in range(3):
                        b=base+k*4;c=b+4
                        faces.extend([(b,c,c+1,b+1),(b+2,b+3,c+3,c+2),(b,b+2,c+2,c),(b+1,c+1,c+3,b+3)])
                    faces.extend([(base,base+1,base+3,base+2),(base+12,base+14,base+15,base+13)])
            mesh(prefix+'five twin swept spokes',verts,faces,alloy,.0017)
            # Bolt sockets plus separate hexagonal fasteners, batched per material.
            for material, radius,depth,label in [(dark,.010,.0905,'bolt pockets'),(steel,.006,.092,'hex bolts')]:
                vs=[];fs=[]; n=18 if material==dark else 6
                for j in range(5):
                    a=j*2*math.pi/5;cx=.045*math.cos(a);cz=.045*math.sin(a);b=len(vs)
                    for k in range(n):
                        t=2*math.pi*k/n;vs.append((x+cx+radius*math.cos(t),y+sign*depth,.29775+cz+radius*math.sin(t)))
                    fs.append(tuple(b+k for k in range(n)))
                mesh(prefix+label,vs,fs,material)
            revolve('center cap ring',[(.021,.091),(.024,.091),(.024,.095),(.021,.096)],alloy)
            revolve('center cap dark',[(0,.094),(.021,.094),(.021,.096),(0,.096)],dark)
            # Small silver VW-like monogram strokes on the cap, actual geometry.
            vv=[];ff=[]
            strokes=[(-.014,.012,-.007,-.005),(-.007,-.005,0,.010),(0,.010,.007,-.005),(.007,-.005,.014,.012),(-.010,-.002,-.006,-.014),(-.006,-.014,0,-.004),(0,-.004,.006,-.014),(.006,-.014,.010,-.002)]
            for ax,az,bx,bz in strokes:
                dx=bx-ax;dz=bz-az;ln=math.hypot(dx,dz); ox=-dz/ln*.0008;oz=dx/ln*.0008;b=len(vv)
                vv.extend([(x+ax+ox,y+sign*.0962,.29775+az+oz),(x+bx+ox,y+sign*.0962,.29775+bz+oz),(x+bx-ox,y+sign*.0962,.29775+bz-oz),(x+ax-ox,y+sign*.0962,.29775+az-oz)])
                ff.append((b,b+1,b+2,b+3))
            mesh(prefix+'cap emblem',vv,ff,alloy)
    return made
