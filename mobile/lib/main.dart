import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:local_auth/local_auth.dart';

void main()=>runApp(const PeoYameApp());
const brand=Color(0xff176b4d);
const secure=FlutterSecureStorage();
class PeoYameApp extends StatelessWidget{
  const PeoYameApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(title:'Peo Yame',theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:brand),scaffoldBackgroundColor:const Color(0xfff1f6f2),appBarTheme:const AppBarTheme(backgroundColor:Color(0xff112821),foregroundColor:Colors.white),inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(borderSide:BorderSide(color:Color(0xff768a80)))),useMaterial3:true),home:const Home());
}
class Home extends StatefulWidget{const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
  final phone=TextEditingController(),password=TextEditingController(),totp=TextEditingController(),name=TextEditingController();
  final address=TextEditingController(text:'http://10.0.2.2:3000');
  final localAuth=LocalAuthentication();
  final pages=['Overview','Trends','My Crops','Alerts','Settings'];
  int tab=0;String screen='welcome',error='',crop='Maize',lastSync='Not synced',mode='instant';
  String? token,qrPayload,qrCodeId,csrf;bool busy=false,offline=false,scanning=false,backendSaved=false,guidedDemoEnabled=false,totpEnabled=false;
  Map<String,dynamic> status={};List<dynamic> sites=[],alerts=[],sessions=[],readings=[];
  Future<void> restore()async{try{final saved=await secure.read(key:'backend');if(saved!=null){address.text=saved;backendSaved=true;}token=await secure.read(key:'session');if(token!=null){mode='farmer';screen='app';await refresh();final account=await api('/api/account');totpEnabled=account['totpEnabled']==true;}}catch(_){}if(backendSaved){try{final health=await api('/api/health',auth:false);guidedDemoEnabled=health['guidedDemoEnabled']==true;}catch(_){}}if(mounted)setState((){});}
  @override void initState(){super.initState();restore();}
  @override void dispose(){phone.dispose();password.dispose();totp.dispose();name.dispose();address.dispose();super.dispose();}
  Uri uri(String p)=>Uri.parse(address.text.replaceAll(RegExp(r'/+$'),'')+p);
  Future<dynamic> api(String p,{String method='GET',Map<String,dynamic>? body,bool auth=true})async{
    final headers=<String,String>{'content-type':'application/json'};
    if(auth&&token!=null)headers['authorization']='Bearer '+token!;
    if(csrf!=null&&method!='GET')headers['x-csrf-token']=csrf!;
    final request=http.Request(method,uri(p))..headers.addAll(headers);
    if(body!=null)request.body=jsonEncode(body);
    final response=await http.Response.fromStream(await request.send()).timeout(const Duration(seconds:8));
    if(response.statusCode==204)return null;
    final data=jsonDecode(response.body.isEmpty?'{}':response.body);
    if(response.statusCode<200||response.statusCode>=300)throw Exception(data is Map?data['error']??'Request failed':'Request failed');
    return data;
  }
  Future<void> refresh()async{
    try{final d=await api('/api/status?crop='+Uri.encodeComponent(crop),auth:mode!='instant');status=Map<String,dynamic>.from(d);offline=false;lastSync=DateTime.now().toLocal().toString();if(tab==2)sites=await api('/api/sites');if(tab==3)alerts=await api('/api/alerts');}
    catch(_){offline=true;}
    if(mounted)setState((){});
  }
  void instantDemo(){mode='instant';token=null;tab=0;screen='app';refresh();}
  Future<void> login()async{setState(()=>busy=true);try{final d=Map<String,dynamic>.from(await api('/api/account/login',method:'POST',auth:false,body:{'phone':phone.text,'password':password.text,'totp':totp.text}));token=d['token'];await secure.write(key:'session',value:token);mode='farmer';screen='app';error='';await refresh();final account=await api('/api/account');totpEnabled=account['totpEnabled']==true;}catch(e){error=e.toString().replaceFirst('Exception: ','');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> register()async{setState(()=>busy=true);try{await api('/api/account/register',method:'POST',auth:false,body:{'name':name.text,'phone':phone.text,'password':password.text});screen='login';error='Account created. Sign in with your phone and password.';}catch(e){error=e.toString().replaceFirst('Exception: ','');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> guidedDemo()async{try{final d=Map<String,dynamic>.from(await api('/api/demo/start',method:'POST',auth:false,body:{'client':'mobile'}));token=d['token'];await secure.write(key:'session',value:token);mode='guided';screen='app';await refresh();}catch(e){_message(e);}}
  Future<void> signOut()async{try{await api('/api/account/logout',method:'POST',body:{});}catch(_){}token=null;csrf=null;await secure.delete(key:'session');if(mounted)setState(()=>screen='welcome');}
  void _message(Object e)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
  String? get estimateText{final e=status['estimate'];if(offline||status['stale']==true||e==null)return null;final r=e['rangeWeeks'];if(r is! List||r.length<2)return null;return 'About '+r[0].toString()+'–'+r[1].toString()+' weeks';}
  Widget card(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:child));
  Widget button(String label,VoidCallback action,{bool primary=false})=>SizedBox(width:double.infinity,child:Padding(padding:const EdgeInsets.only(top:8),child:FilledButton(style:primary?null:FilledButton.styleFrom(backgroundColor:const Color(0xffe1f0e6),foregroundColor:brand),onPressed:busy?null:action,child:Text(label))));
  Widget input(String label,TextEditingController c,{bool secret=false,String? hint,TextInputType? type})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,obscureText:secret,keyboardType:type,decoration:InputDecoration(labelText:label,hintText:hint,border:const OutlineInputBorder(),isDense:true)));
  @override Widget build(BuildContext context){
    if(screen=='camera-rationale')return _rationale();
    if(screen=='scanner')return _scanner();
    if(screen=='waiting')return _waiting();
    if(screen=='app')return _app();
    return Scaffold(backgroundColor:const Color(0xfff1f6f2),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:ListView(padding:const EdgeInsets.all(24),shrinkWrap:true,children:[
      Image.asset('assets/brand/PeoYame-Sorghum-Logo-Master.png',width:72,height:72,alignment:Alignment.centerLeft),
      const SizedBox(height:12),const Text('Welcome to\nPeo Yame',style:TextStyle(fontSize:34,fontWeight:FontWeight.w700,color:brand)),
      const SizedBox(height:10),const Text('Monitor storage conditions and check your crops by hand.'),
      const SizedBox(height:16),if(screen=='login'||screen=='register')...[
        if(screen=='register')input('Full name',name),
        input('Mobile number',phone,hint:'+267 71 234 567',type:TextInputType.phone),
        input('Password',password,secret:true),
        if(screen=='login')input('Authenticator code (if enabled)',totp,type:TextInputType.number),
        if(screen=='register')const Text('Use a password of at least 10 characters.'),
        if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.red)),
        button(screen=='login'?'Sign in':'Create account',screen=='login'?login:register,primary:true),
        if(screen=='login')button('Sign in with QR code',()=>setState(()=>screen='camera-rationale')),
        button(screen=='login'?'Create account':'I already have an account',()=>setState(() {screen=screen=='login'?'register':'login';error='';})),
      ]else ...[
        if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.red)),
        if(!backendSaved)...[input('Backend address',address,hint:'http://192.168.1.20:3000'),button('Check and save backend',saveBackend,primary:true)],
        button('Sign in',()=>setState(()=>screen='login'),primary:true),
        button('Create account',()=>setState(()=>screen='register')),
        button('Explore Demo mode',instantDemo),
        card(const Text('Demo mode uses simulated readings and creates no account.')),
        Text('Backend: '+address.text),
      ],
    ])))));
  }
  Widget _rationale()=>Scaffold(appBar:AppBar(title:const Text('Scan sign-in QR')),body:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.camera_alt_outlined,size:48),const SizedBox(height:16),const Text('We use the camera only to scan the code on your computer.'),const SizedBox(height:8),const Text('QR codes expire after 90 seconds and can be used once.'),button('Continue',()=>setState(()=>screen='scanner'),primary:true),button('Enter code manually',manualCode),button('Not now',()=>setState(()=>screen='login'))])));
  Future<void> manualCode()async{final ctrl=TextEditingController();final value=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Enter code manually'),content:TextField(controller:ctrl,decoration:const InputDecoration(labelText:'Code ID')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,ctrl.text),child:const Text('Continue'))]));if(value!=null&&value.isNotEmpty)await handleQr(jsonEncode({'backend':address.text,'codeId':value}));}
  Widget _scanner()=>Scaffold(appBar:AppBar(title:const Text('Scan sign-in code')),body:Column(children:[const Padding(padding:EdgeInsets.all(12),child:Text('On your computer, open Settings → Connect phone by QR, or choose Sign in with QR code.')),Expanded(child:MobileScanner(onDetect:(capture){if(scanning||capture.barcodes.isEmpty)return;final value=capture.barcodes.first.rawValue;if(value!=null){scanning=true;handleQr(value);}})),const Padding(padding:EdgeInsets.all(12),child:Text('Phone and computer must be on the same Wi-Fi.'))]));
  bool privateAddress(String s){final u=Uri.tryParse(s);if(u==null||u.scheme!='http'||u.port<1)return false;final h=u.host;if(h.startsWith('10.')||h.startsWith('192.168.'))return true;final parts=h.split('.');if(parts.length==4&&parts[0]=='172'){final p=int.tryParse(parts[1])??0;return p>=16&&p<=31;}return false;}
  String randomVerifier(){final r=Random.secure(),bytes=List<int>.generate(32,(_)=>r.nextInt(256));return base64UrlEncode(bytes).replaceAll('=','');}
  Future<void> handleQr(String raw)async{
    try{
      final payload=Map<String,dynamic>.from(jsonDecode(raw));final origin=(payload['backend']??'').toString(),id=(payload['codeId']??'').toString();
      if(!privateAddress(origin)||id.isEmpty)throw Exception('QR must contain a private-network HTTP address and a code ID.');
      if(origin!=address.text){final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Connect to this backend?'),content:Text('Connect to '+origin+'? Your old backend session will be cleared.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Connect'))]));if(yes!=true)return;await secure.delete(key:'session');token=null;address.text=origin;await secure.write(key:'backend',value:origin);backendSaved=true;}
      if(token!=null){final detail=await api('/api/qr/web/scan',method:'POST',body:{'codeId':id,'deviceName':'Android phone'});if(!mounted)return;final ctrl=TextEditingController();final match=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Approve sign-in on computer?'),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Device: '+(detail['device']??'Web browser')),Text('Address: '+(detail['networkAddress']??'Private network')),TextField(controller:ctrl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Enter the match number shown on the computer'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Deny')),TextButton(onPressed:()=>Navigator.pop(c,ctrl.text),child:const Text('Approve'))]));if(match!=null){final ok=await localAuth.authenticate(localizedReason:'Approve this Peo Yame sign-in on your computer');if(!ok)throw Exception('Biometric approval was cancelled.');await api('/api/qr/web/approve',method:'POST',body:{'codeId':id,'matchCode':match});_message('Computer sign-in approved.');}else{await api('/api/qr/web/deny',method:'POST',body:{'codeId':id});}}
      else{final verifier=randomVerifier();final result=await api('/api/qr/phone/scan',method:'POST',auth:false,body:{'codeId':id,'verifier':verifier,'deviceName':'Android phone','appVersion':'1'});await secure.write(key:'pairCode',value:id);await secure.write(key:'pairVerifier',value:verifier);await secure.write(key:'pairMatch',value:result['matchNumber'].toString());setState(()=>screen='waiting');}
    }catch(e){setState(()=>screen='login');_message(e);}finally{scanning=false;}
  }
  Widget _waiting()=>Scaffold(appBar:AppBar(title:const Text('Approve on your computer')),body:FutureBuilder<String?>(future:secure.read(key:'pairMatch'),builder:(c,s)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.shield_outlined,size:54,color:brand),const Text('Approve on your computer'),Text(s.data??'••',style:const TextStyle(fontSize:64,fontWeight:FontWeight.bold)),const Text('Enter this number on your computer. Expires in 90 seconds.'),button('Cancel',()=>setState(()=>screen='login')),const SizedBox(height:12),button('Check approval',redeemPair)])))));
  Future<void> redeemPair()async{try{final id=await secure.read(key:'pairCode'),ver=await secure.read(key:'pairVerifier');final d=await api('/api/qr/'+Uri.encodeComponent(id??''),auth:false);if(d['state']=='expired'||d['state']=='denied')throw Exception('This pairing request expired or was denied.');if(d['state']!='approved')throw Exception('Waiting for approval on your computer.');final result=Map<String,dynamic>.from(await api('/api/qr/phone/redeem',method:'POST',auth:false,body:{'codeId':id,'verifier':ver}));token=result['token'];await secure.write(key:'session',value:token);await secure.delete(key:'pairVerifier');mode='farmer';screen='app';await refresh();}catch(e){_message(e);}}
  Widget _app() {
    final reading = status['reading'] as Map<String, dynamic>?;
    final estimate = estimateText;
    final stale = offline || status['stale'] == true;
    final bands = status['targetBands'] as Map<String, dynamic>?;
    final sensorCount = sites.fold<int>(
      0,
      (count, site) => count + ((site['sensors'] as List?)?.length ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/brand/PeoYame-Sorghum-Logo-Master.png'),
        ),
        title: const Text('Peo Yame'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Chip(
              label: Text(
                mode == 'instant'
                    ? 'Demo data · simulated'
                    : mode == 'guided'
                        ? 'Demo session'
                        : 'Connected',
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(pages[tab], style: Theme.of(context).textTheme.headlineMedium),
            if (mode == 'instant')
              card(const Text('Shared Demo profile · Mr Lesego Lefoko')),
            if (mode == 'guided')
              card(const Text('Demo session. Data is simulated and will be deleted.')),
            if (stale)
              card(Text(
                'Offline · last known values from '
                + ((status['reading'] as Map?)?['createdAt'] ?? 'unknown time').toString(),
              )),
            if (tab == 0) ...[
              card(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text((status['statusLabel'] ?? 'In range').toString())),
                  Text(status['statusLabel'] == 'Outside target band'
                      ? 'Conditions are outside the target band. Check your crop now.'
                      : 'Within configured limits; this does not establish crop safety.'),
                  const SizedBox(height: 12),
                  Text('Temperature  ' + (reading?['temperature'] ?? '18.2').toString() + ' °C',
                      style: const TextStyle(fontSize: 22)),
                  Text('Humidity  ' + (reading?['humidity'] ?? '62').toString() + ' %',
                      style: const TextStyle(fontSize: 22)),
                  Text('Low · Target · High · temperature range '
                      + ((bands?['temperatureC'] as List?)?.join('–') ?? '12–25') + ' °C; humidity range '
                      + ((bands?['humidityPercent'] as List?)?.join('–') ?? '50–70') + ' %'),
                ],
              )),
              card(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Text('Rough storage estimate', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Chip(label: Text('Estimate')),
                  ]),
                  Text(estimate ?? 'Estimate not available while readings are old',
                      style: const TextStyle(fontSize: 24)),
                  const Text('A rough guess from temperature and humidity only. It does not inspect your crop. Check your crops by hand every few days.'),
                  TextButton(onPressed: showEstimateExplanation, child: const Text('How is this estimated?')),
                ],
              )),
              card(Text('Last synced: ' + lastSync + ' · Crop: ' + crop)),
            ] else if (tab == 1) ...[
              card(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, children: [
                    for (final range in ['24h', 'month', '3months'])
                      OutlinedButton(
                        onPressed: () => loadTrends(range),
                        child: Text(range == '24h' ? '24 hours' : range == 'month' ? '1 month' : '3 months'),
                      ),
                  ]),
                  const Text('Temperature (°C) · target band'),
                  const Text('Humidity (%) · target band'),
                  for (final point in readings.take(8))
                    Text(point['created_at'].toString() + ' · ' + point['temperature'].toString()
                        + ' °C · ' + point['humidity'].toString() + ' %'),
                ],
              )),
            ] else if (tab == 2) ...[
              card(Text(sites.length.toString() + ' storage locations · ' + sensorCount.toString() + ' sensors linked')),
              for (final site in sites)
                card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site['crop'].toString() + ' · ' + site['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    for (final sensor in site['sensors'] ?? [])
                      Text(sensor['id'].toString() + ' · ' + (sensor['last_seen_at'] ?? 'No readings').toString()),
                    TextButton(onPressed: () => deleteSite(site['id'].toString()), child: const Text('Delete location')),
                  ],
                )),
              button('Add storage location', addSite, primary: true),
            ] else if (tab == 3) ...[
              card(const Text('Alert log. Text messages are not sent in this edition.')),
              for (final alert in alerts)
                card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['message'] ?? 'Alert'),
                    const Text('SMS not sent'),
                    if (alert['reviewed_at'] == null)
                      TextButton(onPressed: () => reviewAlert(alert['id'].toString()), child: const Text('Mark as reviewed')),
                  ],
                )),
            ] else ...[
              _settings(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() => tab = index);
          refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.grass), label: 'My Crops'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
  Widget _settings()=>Column(children:[
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Account & security',style:TextStyle(fontWeight:FontWeight.bold)),button('Profile',profile),button('Authenticator app · '+(totpEnabled?'On':'Off'),totpEnabled?disableTotp:totpEnroll),button('Active sessions',loadSessions),button('Lock app with biometrics',biometricLock)])),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Connection',style:TextStyle(fontWeight:FontWeight.bold)),input('Backend address',address),button('Check and save backend',saveBackend),const Text('Plain HTTP is for an isolated demo network only. Phone and computer must be on the same Wi-Fi.'),Text('Last synced: '+lastSync)])),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Other devices',style:TextStyle(fontWeight:FontWeight.bold)),button('Connect phone by QR',createPairQr),button('Log in on computer',()=>setState(()=>screen='camera-rationale'))])),
    if(qrPayload!=null)card(Column(children:[QrImageView(data:qrPayload!,size:220),Text('Code expires shortly · '+(qrCodeId??''))])),
    if(sessions.isNotEmpty)card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Active sessions',style:TextStyle(fontWeight:FontWeight.bold)),for(final s in sessions)Text(s['kind'].toString()+' · '+s['expires_at'].toString())])),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Data',style:TextStyle(fontWeight:FontWeight.bold)),button('Export readings',exportData),if(mode!='farmer')button('Demo tools',()=>showDemoTools())])),
    button('Sign out',signOut),
  ]);
  Future<void> showEstimateExplanation()async{await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('How is this estimated?'),content:const Text('An unvalidated heuristic based on distance from target bands. It ignores crop moisture, variety, maturity, pests, packaging and ventilation.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))]));}
  Future<void> loadTrends(String range)async{try{final d=await api('/api/readings/trends?range='+range,auth:mode!='instant');readings=List<dynamic>.from(d['points']??[]);setState(()=>tab=1);}catch(e){_message(e);}}
  Future<void> addSite()async{final n=TextEditingController();final cropCtrl=TextEditingController(text:'Maize');final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Add storage location'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Location name')),DropdownButtonFormField<String>(initialValue:'Maize',items:['Maize','Sorghum','Tomato','Potato'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x){if(x!=null)cropCtrl.text=x;})]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Add'))]));if(ok==true)try{await api('/api/sites',method:'POST',body:{'name':n.text,'crop':cropCtrl.text});sites=await api('/api/sites');setState((){});}catch(e){_message(e);}}
  Future<void> deleteSite(String id)async{try{await api('/api/sites/'+id,method:'DELETE');sites=await api('/api/sites');setState((){});}catch(e){_message(e);}}
  Future<void> reviewAlert(String id)async{try{await api('/api/alerts/'+id+'/review',method:'POST',body:{});alerts=await api('/api/alerts');setState((){});}catch(e){_message(e);}}
  Future<void> loadSessions()async{try{sessions=await api('/api/account/sessions');setState((){});}catch(e){_message(e);}}
  Future<void> createPairQr()async{try{final pass=TextEditingController();final auth=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Confirm your identity'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password')),TextField(controller:auth,decoration:const InputDecoration(labelText:'Authenticator code (if enabled)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Continue'))]));if(ok!=true)return;final d=await api('/api/qr/phone/create',method:'POST',body:{'password':pass.text,'totp':auth.text});qrPayload=d['payload'];qrCodeId=d['codeId'];setState((){});}catch(e){_message(e);}}
  Future<void> profile()async{try{final x=await api('/api/account');_message('Signed in as '+x['name'].toString()+' · '+x['phone'].toString());}catch(e){_message(e);}}
  Future<Map<String, String>?> askReauthentication({bool needTotp = false}) async {
    final pass = TextEditingController();
    final code = TextEditingController();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm your identity'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (needTotp) TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, {'password': pass.text, 'totp': code.text}), child: const Text('Continue')),
          ],
        ),
      );
    } finally {
      pass.dispose();
      code.dispose();
    }
  }
  Future<void> totpEnroll() async {
    final credentials = await askReauthentication(needTotp: totpEnabled);
    if (credentials == null) return;
    final code = TextEditingController();
    try {
      final d = await api('/api/account/totp/enroll', method: 'POST',
          body: {'password': credentials['password'], 'totp': credentials['totp']});
      if (!mounted) return;
      final enabled = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Set up authenticator app'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            QrImageView(data: d['uri'].toString(), size: 200),
            const Text('Scan this code, or enter the setup key manually:'),
            SelectableText(d['secret'].toString()),
            TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-digit authenticator code')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enable')),
          ],
        ),
      );
      if (enabled == true) {
        final result = Map<String, dynamic>.from(await api('/api/account/totp/enable',
            method: 'POST', body: {'password': credentials['password'], 'code': code.text}));
        if (result['token'] is String) {
          token = result['token'];
          await secure.write(key: 'session', value: token);
        }
        totpEnabled = true;
        _message('Authenticator sign-in enabled. Other sessions were signed out.');
      }
    } catch (e) {
      _message(e);
    } finally {
      code.dispose();
      if (mounted) setState(() {});
    }
  }
  Future<void> disableTotp() async {
    final credentials = await askReauthentication(needTotp: true);
    if (credentials == null) return;
    try {
      final result = Map<String, dynamic>.from(await api('/api/account/totp/disable',
          method: 'POST', body: {'password': credentials['password'], 'code': credentials['totp']}));
      if (result['token'] is String) {
        token = result['token'];
        await secure.write(key: 'session', value: token);
      }
      totpEnabled = false;
      _message('Authenticator sign-in disabled. Other sessions were signed out.');
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() {});
    }
  }
  Future<void> biometricLock()async{try{final ok=await localAuth.authenticate(localizedReason:'Unlock Peo Yame');if(!ok)throw Exception('Authentication cancelled.');_message('Biometric check passed on this device.');}catch(e){_message(e);}}
  Future<void> saveBackend()async{try{if(!privateAddress(address.text))throw Exception('Use a private network HTTP address.');final d=await api('/api/health',auth:false);if(d['ok']!=true)throw Exception('Wrong server');await secure.write(key:'backend',value:address.text);backendSaved=true;await secure.delete(key:'session');token=null;_message('Connected · accounts enabled');if(mounted)setState((){});}catch(e){_message('Backend unreachable or wrong server: '+e.toString());}}
  Future<void> exportData()async{try{final d=await api('/api/export');_message('Export ready: '+d.toString().substring(0,min(80,d.toString().length)));}catch(e){_message(e);}}
  Future<void> showDemoTools()async{showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Wrap(children:[const ListTile(title:Text('Demo tools'),subtitle:Text('Simulated readings · SMS not sent')),ListTile(title:const Text('Simulate breach'),onTap:()=>simulateBreach()),if(guidedDemoEnabled)ListTile(title:const Text('Start guided demo'),onTap:()=>guidedDemo()),ListTile(title:const Text('Reset demo'),onTap:resetDemo)])));}
  Future<void> simulateBreach()async{if(mode=='instant'){status={'reading':{'temperature':33,'humidity':88,'createdAt':DateTime.now().toIso8601String(),'synthetic':true},'stale':false,'estimate':{'rangeWeeks':[1,2]}};setState((){});return;}try{await api('/api/demo/simulate-reading',method:'POST',body:{'temperature':33,'humidity':88,'sensorId':'PY-DEMO-1'});await refresh();}catch(e){_message(e);}}
  Future<void> resetDemo()async{try{await api('/api/demo/reset',method:'POST',body:{});await secure.delete(key:'session');token=null;mode='instant';instantDemo();}catch(e){_message(e);}}
}