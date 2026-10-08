import bpy, math, importlib.util
from mathutils import Vector, Quaternion
from pathlib import Path
OUT=Path(r'C:\Users\satoshi\Documents\ChatGPT\teste')
scene=bpy.data.scenes.new('Voyage | Reconstruction 03')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.length_unit='METERS'
root=bpy.data.objects.new('VOYAGE | exterior assembly',None)
scene.collection.objects.link(root)
cols={}
for name in ['Body panels','Glazing','Lighting','Wheels','Details','Studio','References']:
    c=bpy.data.collections.new(name); scene.collection.children.link(c); cols[name]=c

def mat(name,c,metal=0,rough=.3):
    m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*c,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
paint=mat('Silver | coated automotive paint',(.49,.51,.53),.75,.24)
glass=mat('Glass | smoked charcoal',(.018,.028,.036),.28,.12)
black=mat('Rubber seals and ABS',(.009,.011,.014),0,.38)
chrome=mat('Brushed aluminium',(.6,.65,.7),.93,.21)
red=mat('Red polycarbonate lenses',(.36,.004,.012),.24,.18)
lens=mat('Headlight optical cover',(.16,.21,.26),.48,.15)
white=mat('Reflector and plate',(.83,.84,.84),.15,.25)

def mesh(name,vs,fs,m,col='Body panels',solid=0):
    data=bpy.data.meshes.new(name); data.from_pydata(vs,[],fs); data.update()
    ob=bpy.data.objects.new(name,data); cols[col].objects.link(ob); ob.parent=root; data.materials.append(m)
    for p in data.polygons:p.use_smooth=True
    if solid:
        mod=ob.modifiers.new('Sheet thickness','SOLIDIFY');mod.thickness=solid;mod.offset=-1
    return ob
def grid(name,fn,nu,nv,m,col='Body panels',solid=.001):
    vs=[fn(i/nu,j/nv) for i in range(nu+1) for j in range(nv+1)]
    fs=[(i*(nv+1)+j,(i+1)*(nv+1)+j,(i+1)*(nv+1)+j+1,i*(nv+1)+j+1) for i in range(nu) for j in range(nv)]
    return mesh(name,vs,fs,m,col,solid)
def line(name,ps,m=black,r=.002,col='Details',cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=3
    sp=cu.splines.new('POLY');sp.points.add(len(ps)-1)
    for p,co in zip(sp.points,ps):p.co=(*co,1)
    sp.use_cyclic_u=cyclic
    ob=bpy.data.objects.new(name,cu);cols[col].objects.link(ob);cu.materials.append(m);ob.parent=root;return ob
def interp(points,x):
    # Cubic Hermite with shared derivatives avoids a flat tangent at every station.
    if x<=points[0][0]:return points[0][1]
    for k,((a,v),(b,w)) in enumerate(zip(points,points[1:])):
        if x<=b:
            t=(x-a)/(b-a);h=b-a
            prev=points[max(0,k-1)];nxt=points[min(len(points)-1,k+2)]
            m0=(w-prev[1])/(b-prev[0]);m1=(nxt[1]-v)/(nxt[0]-a)
            return (2*t**3-3*t*t+1)*v+(t**3-2*t*t+t)*h*m0+(-2*t**3+3*t*t)*w+(t**3-t*t)*h*m1
    return points[-1][1]
def width(x):return interp([(-2.05,.715),(-1.85,.795),(-1.35,.826),(-.7,.821),(.4,.815),(1.3,.828),(1.92,.794),(2.165,.738)],x)
def belt(x):return interp([(-2.05,.89),(-1.6,.93),(-.8,.995),(.2,1.0),(1.15,1.035),(1.65,1.025),(2.165,.985)],x)
def lower(x):
    z=.205
    for xc in [-1.2325,1.2325]:
        d=abs(x-xc);r=.337
        if d<r:z=max(z,.29775+math.sqrt(r*r-d*d))
    return z
def side_y(x,z):
    top=belt(x);t=max(0,min(1,(z-.205)/(top-.205)))
    return width(x)-.061*(1-t)**2+.006*math.sin(math.pi*t)-.045*t**8-.008*math.exp(-((t-.15)/.13)**2)
def side(x,z,s):
    xx=x
    if x< -1.85:xx+=.095*(max(0,(-1.85-x)/.2))**2
    if x>1.965:xx-=.095*(max(0,(x-1.965)/.2))**2
    return (xx,s*side_y(x,z),z)
# Side sheets stop at the wheel arcs explicitly; no Boolean/Subdivision collapse.
for s in [-1,1]:
    grid('Left body sheet' if s>0 else 'Right body sheet',lambda u,v:(lambda x:side(x,lower(x)+(belt(x)-lower(x))*v,s))(-2.05+4.215*u),340,16,paint)
    for xc in [-1.2325,1.2325]:
        def arch(u,v,xc=xc,s=s):
            a=math.pi*u;rr=.337+.014*v;x=xc+rr*math.cos(a);z=.29775+rr*math.sin(a)
            return (x,s*(side_y(x,z)+.003*math.sin(math.pi*v)),z)
        grid('Rolled fender lip',arch,70,4,paint,solid=.0015)
        grid('Wheelhouse liner',lambda u,v,xc=xc,s=s:(xc+.337*math.cos(math.pi*u),s*(.66+.14*v),.29775+.337*math.sin(math.pi*u)),60,8,black,solid=.002)

# Curved hood and separate trunk surface, sharing the shoulder boundary exactly.
def deck(x,v):
    t=2*v-1;xx=x
    if x< -1.85:xx+=.095*abs(t)**3*(max(0,(-1.85-x)/.2))**2
    if x>1.965:xx-=.095*abs(t)**3*(max(0,(x-1.965)/.2))**2
    return(xx,t*side_y(x,belt(x)),belt(x)+.035*(1-t*t))
grid('Hood and forward fenders',lambda u,v:deck(-2.05+1.27*u,v),60,36,paint)
grid('Trunk lid and rear quarters',lambda u,v:deck(1.38+.785*u,v),40,36,paint)

# Greenhouse: flat broad roof, sloping A/C pillars, ruled side surfaces.
roof_keys=[(-.78,.997),(-.56,1.19),(-.28,1.395),(-.08,1.438),(.45,1.447),(.78,1.416),(1.08,1.245),(1.38,1.045)]
def railz(x):return interp(roof_keys,x)
def raily(x):return interp([(-.78,.80),(-.28,.665),(.45,.665),(.78,.67),(1.38,.805)],x)
def cabin(x,v,s):
    z=belt(x)+(railz(x)-belt(x))*v
    base_y=side_y(x,belt(x));y=base_y+(raily(x)-base_y)*v
    return(x,s*y,z)
for s in [-1,1]:
    # Glazing surface is itself the cabin side; borders are complementary panels.
    grid('Side glazing',lambda u,v,s=s:(lambda p:(p[0],p[1]-s*.002,p[2]))(cabin(-.78+2.16*u,v,s)),100,20,glass,'Glazing',.004)
    for label,v0,v1 in [('Window sill',0,.07),('Roof side rail',.925,1)]:
        grid(label,lambda u,v,s=s,v0=v0,v1=v1:cabin(-.78+2.16*u,v0+(v1-v0)*v,s),100,4,paint)
    for label,x0,x1 in [('A pillar',-.78,-.70),('B pillar',.14,.235),('C pillar',1.09,1.38)]:
        grid(label,lambda u,v,s=s,x0=x0,x1=x1:(lambda p:(p[0],p[1]+s*.0015,p[2]))(cabin(x0+(x1-x0)*u,v,s)),18,18,black if label=='B pillar' else paint)
    for vv in [.065,.928]:
        line('Window gasket',[cabin(-.72+1.87*i/100,vv,s) for i in range(101)],r=.003)

def roof(x,v):
    t=2*v-1;return(x,t*raily(x),railz(x)+.015*(1-t*t))
grid('Windscreen',lambda u,v:roof(-.78+.50*u,v),35,42,glass,'Glazing',.004)
grid('Roof painted panel',lambda u,v:roof(-.28+1.06*u,v),50,42,paint)
grid('Rear windscreen',lambda u,v:roof(.78+.60*u,v),35,42,glass,'Glazing',.004)
for x in [-.78,-.28,.78,1.38]:line('Screen seal',[roof(x,i/60) for i in range(61)],r=.004)

# Curved end caps support every lamp, grille and badge by the same coordinates.
def end(v,z,front=True,offset=0):
    xx=-2.05 if front else 2.165
    # Plan-view sweep into the fenders, and tucked lower bumper.
    sign=-1 if front else 1
    tuck=interp([(.205,.065),(.28,.015),(.43,0),(.54,.012),(.64,.05),(.73,.035),(.89,0),(.985,0)],z) if front else .04*max(0,(.36-z)/.16)
    x=xx-sign*(.095*abs(v)**3+tuck) + sign*offset
    return(x,v*side_y(xx,z),z)
for front in [True,False]:
    grid('Front bumper fascia' if front else 'Rear bumper fascia',lambda u,v,front=front:end(2*u-1,.205+(.89-.205 if front else .985-.205)*v,front),64,30,paint)
def end_patch(name,v0,v1,z0,z1,m,front=True):
    return grid(name,lambda u,v:end(v0+(v1-v0)*u,z0+(z1-z0)*v,front,.002),30,10,m,'Lighting' if m in [lens,red] else 'Details',.001)
end_patch('Upper grille',-.54,.54,.755,.87,black)
end_patch('Lower grille',-.73,.73,.29,.445,black)
for z in [.78,.815,.85]:line('Grille slat',[end(-.54+1.08*i/50,z,True,.005) for i in range(51)],chrome,.004)
# Honeycomb mesh assembled in one curve to avoid heavy object overhead.
cu=bpy.data.curves.new('Lower grille honeycomb','CURVE');cu.dimensions='3D';cu.bevel_depth=.0016;cu.bevel_resolution=1
for row in range(5):
    z=.308+row*.029
    for k in range(28):
        yy=-.48+k*.035+(row%2)*.0175
        if abs(yy)>.5:continue
        sp=cu.splines.new('POLY');sp.points.add(5);sp.use_cyclic_u=True
        for j,p in enumerate(sp.points):
            a=math.pi*j/3;p.co=(*end((yy+.019*math.cos(a))/.715,z+.016*math.sin(a),True,.006),1)
ob=bpy.data.objects.new('Honeycomb grille',cu);cols['Details'].objects.link(ob);ob.parent=root;cu.materials.append(black)
for s in [-1,1]:
    end_patch('Headlamp smoked enclosure',s*.56,s*.99,.744,.886,lens)
    # Lamp continues around the front corner, bonded to the fender surface.
    def lamp_side(u,v,s=s):
        x=-2.05+.36*u
        z0=.744+.075*u
        z1=belt(x)-.009
        p=side(x,z0+(z1-z0)*v,s)
        return(p[0]-.001,p[1]+s*.002,p[2])
    grid('Headlamp wraparound lens',lamp_side,24,8,lens,'Lighting',.001)
    line('Headlamp upper housing',[lamp_side(i/40,1) for i in range(41)],black,.003)
    line('Headlamp lower housing',[lamp_side(i/40,0) for i in range(41)],black,.003)
    line('Headlamp side reflector',[lamp_side(.12+.60*i/30,.35) for i in range(31)],chrome,.009)
    for vv in [.66,.85]:
        line('Headlamp reflector ring',[end(s*(vv+.065*math.cos(t*2*math.pi/48)),.824+.038*math.sin(t*2*math.pi/48),True,.005) for t in range(49)],chrome,.006)
    end_patch('Fog light recess',s*.75,s*.94,.365,.465,black)
    end_patch('Fog light lens',s*.79,s*.90,.39,.417,lens)
    end_patch('Tail lamp',s*.52,s*.99,.735,.868,red,False)
    end_patch('Trunk lamp',s*.32,s*.515,.768,.868,red,False)
    end_patch('Bumper reflector',s*.68,s*.89,.285,.307,red,False)
end_patch('Front plate',-.285,.285,.48,.57,white)
end_patch('Rear plate',-.285,.285,.455,.56,white,False)
for front,z in [(True,.813),(False,.80)]:
    ps=[end(.083*math.cos(t*2*math.pi/64)/width(-2.05 if front else 2.165),z+.083*math.sin(t*2*math.pi/64),front,.01) for t in range(65)]
    line('VW roundel',ps,chrome,.007)
    for pts in [[(-.044,.045),(0,-.008),(.044,.045)],[(-.053,.012),(-.028,-.043),(0,-.013),(.028,-.043),(.053,.012)]]:
        line('VW lettering',[end(y/width(-2.05 if front else 2.165),z+zz,front,.011) for y,zz in pts],chrome,.006)

# Flush door seams follow the exact side skin. Handle forms grow from the sheet.
def sphere(name,loc,scale,m,col='Details'):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28,ring_count=14,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o.parent=root
    for c in list(o.users_collection):c.objects.unlink(o)
    cols[col].objects.link(o);o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    return o
for s in [-1,1]:
    for x in [-.75,.18,.98]:
        bottom=max(lower(x)+.012,.265)
        line('Door vertical gap',[side(x,bottom+(belt(x)-bottom)*i/60,s) for i in range(61)],r=.0022)
    line('Door lower gap',[side(-.75+1.68*i/120,.265,s) for i in range(121)],r=.002)
    for x in [.02,.86]:
        z=belt(x)-.11;y=side_y(x,z)
        sphere('Handle recess',(x,s*(y+.001),z),(.080,.003,.025),black)
        sphere('Painted door handle',(x,s*(y+.009),z+.004),(.075,.012,.013),paint)
    x=-.64;z=1.01;y=side_y(x,z)
    line('Mirror support',[(x,s*y,z),(x-.015,s*.887,z+.02)],black,.022)
    sphere('Painted mirror housing',(x-.025,s*.916,z+.035),(.112,.06,.051),paint)
    sphere('Mirror glass',(x+.065,s*.92,z+.038),(.008,.047,.035),glass)
    line('Rocker panel edge',[side(-.90+1.8*i/100,.225,s) for i in range(101)],paint,.01)
    line('Hood seam',[deck(-1.95+1.17*i/80,.115 if s<0 else .885) for i in range(81)],black,.0018)
# Fuel door flush on left rear quarter.
line('Fuel flap',[side(1.24+.092*math.cos(t*2*math.pi/80),.849+.092*math.sin(t*2*math.pi/80),1) for t in range(81)],black,.0016)
base=roof(.75,.5);sphere('Antenna foot',base,(.035,.024,.012),black)
line('Roof antenna',[base,(base[0]+.18,0,base[2]+.19)],black,.004)
# Wipers on windscreen.
for yy in [-.35,.18]:line('Windscreen wiper',[(-.745,yy,1.009),(-.645,yy+.28,1.105)],black,.005)

# Interior silhouettes visible through the dark glazing at grazing angles.
interior=mat('Interior textile',(.035,.038,.042),0,.85)
for x in [-.1,.69]:
    for y in [-.33,.33]:
        sphere('Seat back',(x,y,.94),(.11,.19,.255),interior)
        sphere('Head restraint',(x,y,1.19),(.065,.105,.075),interior)

wheel_spec=importlib.util.spec_from_file_location('voyage_wheels_v3',str(OUT/'voyage_wheels_v3.py'))
wheel_module=importlib.util.module_from_spec(wheel_spec);wheel_spec.loader.exec_module(wheel_module)
wheel_objects=wheel_module.build_wheels(root,cols['Wheels'])
# Neutral studio for surface review.
scene.world=bpy.data.worlds.new('Studio environment');scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.24,.27,.32,1);bg.inputs[1].default_value=.45
floor=mat('Studio porcelain',(.24,.26,.29),0,.45)
grid('Studio floor',lambda u,v:(-100+200*u,-100+200*v,-.008),1,1,floor,'Studio',0)
for name,loc,power,size in [('Key',(-3,-4,6),1400,5),('Fill',(1,4,5),1700,4),('Rim',(4,-2,4),1300,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);cols['Studio'].objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',cd);cols['Studio'].objects.link(cam)
cam.location=(-6.3,-7.2,3.1);cam.rotation_euler=(Vector((0,0,.75))-cam.location).to_track_quat('-Z','Y').to_euler();cd.lens=58;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'voyage_rebuild_review.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.overlay.show_overlays=False
        area.spaces.active.shading.color_type='MATERIAL'
scene['status']='Work in progress: reference matching and exterior review required'
scene['wheelbase_m']=2.465
scene['reference']='User supplied silver sedan images; model year attribution remains unverified'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'voyage_rebuild_v3.blend'))
result={'scene':scene.name,'objects':len(scene.objects),'file':bpy.data.filepath}
