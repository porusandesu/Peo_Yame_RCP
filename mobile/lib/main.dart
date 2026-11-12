import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

const green=Color(0xff176b4d),darkGreen=Color(0xff0f4a35),ink=Color(0xff14231b),muted=Color(0xff5c6e64),canvas=Color(0xfff1f6f2),line=Color(0xffdde6df),inputBorder=Color(0xff768a80),statusGreen=Color(0xff1f7a52),statusGreenBg=Color(0xffe3f4ea),statusWarning=Color(0xff8a6516),statusWarningBg=Color(0xfffff3d6),statusDanger=Color(0xffb3382c),statusDangerBg=Color(0xfffbe9e7);
const storage=FlutterSecureStorage();
final deviceAuth=LocalAuthentication();
String formatPhone(Object? value){var digits=(value??'').toString().replaceAll(RegExp(r'\D'),'');if(digits.startsWith('267')&&digits.length==11)digits=digits.substring(3);if(digits.length!=8)return (value??'').toString();return '+267 ${digits.substring(0,2)} ${digits.substring(2,5)} ${digits.substring(5)}';}
String formatTemperature(num value)=>'${value.toStringAsFixed(1)}\u00a0°C';
String formatHumidity(num value)=>'${value.toStringAsFixed(0)}\u00a0%';
String readingAgeCaption(int seconds)=>seconds>60?'Simulated readings are paused':'Simulated · updated $seconds s ago';
String partialNetworkAddress(Object? address){final value=(address??'Unavailable').toString();if(RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(value))return value.replaceFirst(RegExp(r'\.\d{1,3}$'),'.•••');return value.length>4?'${value.substring(0,4)}•••':'Address partially hidden';}
String maskedBackendAddress(Object? address){final value=(address??'').toString();final uri=Uri.tryParse(value);if(uri==null||!uri.hasAuthority)return partialNetworkAddress(value);return '${uri.scheme}://${partialNetworkAddress(uri.host)}${uri.hasPort?':${uri.port}':''}';}
class GaugePosition{final double fraction,bandStart,bandEnd;final String state;const GaugePosition(this.fraction,this.bandStart,this.bandEnd,this.state);}
GaugePosition gaugePosition(double? value,num lowerBound,num upperBound,{bool percent=false}){
 final low=lowerBound.toDouble(),high=upperBound.toDouble();
 final width=high-low;
 var minimum=low-width/2,maximum=high+width/2;
 if(percent){minimum=max(0.0,minimum).toDouble();maximum=min(100.0,maximum).toDouble();}
 final span=max(0.000001,maximum-minimum).toDouble();
 final state=value==null?'No reading':value<low?'Below target':value>high?'Above target':'In range';
 final fraction=value==null ? .5 :((value-minimum)/span).clamp(0.0,1.0).toDouble();
 return GaugePosition(fraction,((low-minimum)/span).clamp(0.0,1.0).toDouble(),((high-minimum)/span).clamp(0.0,1.0).toDouble(),state);
}
Future<void> _loadPresenterPreflight({bool force=false})async{
 if(preflightLoading||(!force&&preflightCheckedAt!=null&&DateTime.now().difference(preflightCheckedAt!)<const Duration(seconds:30)))return;
 preflightLoading=true;
 try{
  final results=await Future.wait<dynamic>([
   request('/backend/qr',auth:false),
   if(guided)request('/account/sessions'),
  ]);
  detectedLanAddress=(results.first as Map<String,dynamic>)['baseUrl']?.toString();
  presenterSessions=guided?List<dynamic>.from(results[1] as List):[];
  showLanAddress=false;
  preflightError=null;
 }catch(e){detectedLanAddress=null;presenterSessions=[];showLanAddress=false;preflightError=e.toString().replaceFirst('Exception: ','');}
 finally{preflightCheckedAt=DateTime.now();preflightLoading=false;}
}
List<double> niceTicks(double minimum,double maximum){
 if(!minimum.isFinite||!maximum.isFinite)return const [];
 if(maximum<=minimum){minimum-=1;maximum+=1;}
 final magnitude=pow(10,(log((maximum-minimum)/4)/ln10).floor()).toDouble();
 final candidates=[1.0,2.0,2.5,5.0,10.0].map((step)=>step*magnitude).toList();
 double? selected;
 for(final step in candidates){final count=(maximum/step).ceil()-(minimum/step).floor()+1;if(count>=4&&count<=6){selected=step;break;}}
 final step=selected??candidates.last;
 final first=(minimum/step).floor(),last=(maximum/step).ceil();
 return List<double>.generate(last-first+1,(index)=>(first+index)*step);
}
void main()=>runApp(const PeoYameApp());
bool isPrivateBackendUrl(Uri uri){
 if(!uri.hasAuthority||uri.host.isEmpty)return false;
 if(uri.userInfo.isNotEmpty)return false;
 if(uri.scheme=='https')return true;
 if(uri.scheme!='http')return false;
 final host=uri.host;
 if(host=='localhost')return true;
 final address=host.startsWith('[')&&host.endsWith(']')?host.substring(1,host.length-1):host;
 if(address=='::1')return true;
 final parsed=InternetAddress.tryParse(address);
 if(parsed==null||parsed.type!=InternetAddressType.IPv4)return false;
 final octets=parsed.rawAddress;
 return octets[0]==127||octets[0]==10||
  (octets[0]==192&&octets[1]==168)||
  (octets[0]==172&&octets[1]>=16&&octets[1]<=31);
}
class PeoYameApp extends StatelessWidget{const PeoYameApp({super.key});@override Widget build(BuildContext context)=>MaterialApp(title:'Peo Yame',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:green).copyWith(primary:green),scaffoldBackgroundColor:canvas,appBarTheme:const AppBarTheme(backgroundColor:Color(0xff112821),foregroundColor:Colors.white),cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:line))),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:13),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(12)),borderSide:const BorderSide(color:inputBorder)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(12)),borderSide:const BorderSide(color:inputBorder)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(12)),borderSide:const BorderSide(color:green,width:2))),navigationBarTheme:const NavigationBarThemeData(backgroundColor:Colors.white,indicatorColor:Color(0xffe1f0e6))),home:const Home());}
class Home extends StatefulWidget{const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home> with WidgetsBindingObserver{
 List<dynamic> demoSteps=[];
 List<dynamic> presenterSessions=[];
 Timer? ageTicker;
 DateTime? readingCreatedAt;
 DateTime? demoSessionExpiresAt,preflightCheckedAt;
 String? detectedLanAddress,preflightError;
 bool preflightLoading=false,showLanAddress=false;
 bool autoAlerts=true;
 bool manualQrEntry=false;
 final address=TextEditingController(text:'http://10.0.2.2:3000'),phone=TextEditingController(),password=TextEditingController(),confirmPassword=TextEditingController(),name=TextEditingController(),siteName=TextEditingController(),sensorId=TextEditingController(),totpCode=TextEditingController();bool needsTotp=false;String backendStatus='Not checked',savedBackend='http://10.0.2.2:3000';
 final pages=['Overview','Trends','My Crops','Alerts','Settings'];int tab=0;bool entered=false,instant=false,guided=false,demoSimulationActive=false,offline=false,simulatedOffline=false,loading=false,showBackendAddress=false,guidedDemoEnabled=false,appLockEnabled=false,appLocked=false,authPromptActive=false,eventsStarted=false;int consecutiveFailures=0,eventGeneration=0,trendCount=0;String entryMode='welcome',crop='Maize',lastSync='Not synced',error='',trendRange='24h';String? token,inspectionSiteId;Timer? poll;http.Client? eventClient;Map<String,dynamic> data={},trendSummary={};List<dynamic> sites=[],sensors=[],alerts=[],trends=[],catalog=[];
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);restore();poll=Timer.periodic(const Duration(seconds:30),(_)=>refresh());ageTicker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});unawaited(_loadDemoStatus());}
 Future<void> _loadDemoStatus()async{try{final health=Map<String,dynamic>.from(await request('/health',auth:false));guidedDemoEnabled=health['guidedDemoEnabled']==true;if(mounted)setState((){});}catch(_){}}
 Future<void> restore()async{try{final a=await storage.read(key:'backend');final t=await storage.read(key:'session');appLockEnabled=await storage.read(key:'appLockEnabled')=='true';if(a!=null){address.text=a;savedBackend=a;}token=t;if(t!=null){entered=true;if(appLockEnabled)appLocked=true;final initial=Map<String,dynamic>.from(await request('/status'));crop=(initial['crop']??'Maize').toString();await refresh();try{final account=await request('/account');guided=account['isDemo']==true;}catch(_){}startEvents();}}catch(_){}if(mounted)setState((){});}
 @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.paused&&appLockEnabled&&token!=null&&!instant){setState(()=>appLocked=true);stopEvents();}if(state==AppLifecycleState.resumed&&appLocked&&!authPromptActive){_unlockApp();}}
 Future<void> _unlockApp()async{if(authPromptActive)return;authPromptActive=true;try{final supported=await deviceAuth.isDeviceSupported();if(!supported)throw Exception('Set up a device lock before using biometric app lock.');final ok=await deviceAuth.authenticate(localizedReason:'Unlock Peo Yame',biometricOnly:true);if(ok&&mounted){setState(()=>appLocked=false);await refresh(manual:true);}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{authPromptActive=false;}}
 @override void dispose(){WidgetsBinding.instance.removeObserver(this);poll?.cancel();ageTicker?.cancel();eventGeneration++;eventClient?.close();for(final c in [address,phone,password,confirmPassword,name,siteName,sensorId,totpCode]){c.dispose();}super.dispose();}
 Uri url(String path)=>Uri.parse(savedBackend.replaceAll(RegExp(r'/+$'),'')+'/api'+path);
 Future<dynamic> request(String path,{String method='GET',Map<String,dynamic>? body,bool auth=true})async{final headers={'content-type':'application/json'};if(auth&&token!=null)headers['authorization']='Bearer $token';final r=http.Request(method,url(path))..headers.addAll(headers);if(body!=null)r.body=jsonEncode(body);final client=http.Client();try{final response=await client.send(r).timeout(const Duration(seconds:8));final text=await response.stream.bytesToString();final d=text.isEmpty?<String,dynamic>{}:jsonDecode(text);if(response.statusCode<200||response.statusCode>=300){if(response.statusCode==401&&auth&&token!=null)await _sessionExpired();throw Exception(d is Map<String,dynamic>&&d['error']!=null?d['error']:'Request failed');}return d;}finally{client.close();}}
 void startEvents(){eventsStarted=true;eventGeneration++;eventClient?.close();unawaited(_eventLoop(eventGeneration));}
 Future<void> _eventLoop(int generation)async{var failures=0;while(mounted&&entered&&generation==eventGeneration){final client=http.Client();eventClient=client;try{final eventRequest=http.Request('GET',url('/events'));if(token!=null)eventRequest.headers['authorization']='Bearer $token';final response=await client.send(eventRequest).timeout(const Duration(seconds:8));if(response.statusCode==401&&token!=null){await _sessionExpired();return;}if(response.statusCode!=200)throw Exception('Event stream unavailable');failures=0;consecutiveFailures=0;if(offline&&mounted)setState(()=>offline=false);await refresh();var eventName='';await for(final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())){if(line.startsWith('event:'))eventName=line.substring(6).trim();if(line.isEmpty){if(eventName.isNotEmpty&&eventName!='connected')unawaited(refresh(manual:true));eventName='';}}throw Exception('Event stream ended');}catch(_){if(generation!=eventGeneration||!mounted)return;failures++;consecutiveFailures++;if(consecutiveFailures>=2)offline=true;if(mounted)setState((){});final delay=min(30,1<<failures.clamp(1,5).toInt()).toInt();await Future.delayed(Duration(seconds:delay));}finally{client.close();}}}
 void stopEvents(){eventsStarted=false;eventGeneration++;eventClient?.close();eventClient=null;}
 Future<void> _sessionExpired()async{stopEvents();await storage.delete(key:'session');token=null;entered=false;instant=false;guided=false;if(mounted)setState(()=>error='Session expired. Please sign in again.');}
 Future<void> refresh({bool manual=false})async{
  if(appLocked)return;
  if(simulatedOffline){offline=true;if(manual)consecutiveFailures=0;if(mounted)setState((){});return;}
  try{
   final health=Map<String,dynamic>.from(await request('/health',auth:false));
   guidedDemoEnabled=health['guidedDemoEnabled']==true;
   catalog=List<dynamic>.from(await request('/crops',auth:!instant));
   final v=Map<String,dynamic>.from(await request('/status?crop=${Uri.encodeComponent(crop)}',auth:!instant));
   data=v;
   crop=(v['crop']??crop).toString();
   readingCreatedAt=DateTime.tryParse((v['reading'] as Map<String,dynamic>?)?['createdAt']?.toString()??'')?.toLocal();
   demoSessionExpiresAt=DateTime.tryParse(v['sessionExpiresAt']?.toString()??'')?.toLocal();
   if(v['isDemo']==true)guided=true;
   if(guided){final simulation=Map<String,dynamic>.from(await request('/demo/simulation'));demoSimulationActive=simulation['active']==true;autoAlerts=simulation['autoAlerts']!=false;final checklist=Map<String,dynamic>.from(await request('/demo/checklist'));demoSteps=List<dynamic>.from(checklist['steps']??const []);}
   if(tab==4&&(guided||instant))await _loadPresenterPreflight();
   final syncedAt=DateTime.parse(v['lastSyncedAt'] as String).toLocal();
   lastSync="${syncedAt.hour.toString().padLeft(2,'0')}:${syncedAt.minute.toString().padLeft(2,'0')}:${syncedAt.second.toString().padLeft(2,'0')}";
   consecutiveFailures=0;offline=false;
   if(token!=null&&!instant){sites=List<dynamic>.from(await request('/sites'));sensors=List<dynamic>.from(await request('/sensors'));if(sites.isNotEmpty&&inspectionSiteId==null)inspectionSiteId=sites.first['id'] as String?;}
   if(tab==3)alerts=List<dynamic>.from(await request('/alerts?crop=${Uri.encodeComponent(crop)}',auth:!instant));
   if(tab==1){final t=await request('/readings/trends?range=$trendRange&crop=${Uri.encodeComponent(crop)}',auth:!instant);if(t is Map<String,dynamic>){trends=List<dynamic>.from(t['points']??const []);trendSummary=t['summary'] is Map<String,dynamic>?Map<String,dynamic>.from(t['summary'] as Map):<String,dynamic>{};trendCount=(t['count'] as num?)?.toInt()??trends.length;}else{trends=List<dynamic>.from(t);trendSummary={};trendCount=trends.length;}}
  }catch(_){consecutiveFailures++;if(consecutiveFailures>=2)offline=true;}
  if(token!=null&&entered&&!instant&&!eventsStarted)startEvents();
  if(mounted)setState((){});
 }
 Future<void> _toggleDemoSimulation()async{try{final result=Map<String,dynamic>.from(await request(demoSimulationActive?'/demo/simulation/stop':'/demo/simulation/start',method:'POST'));demoSimulationActive=result['active']==true;await refresh(manual:true);if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(demoSimulationActive?'Simulated readings started. New readings sync every 3 seconds across signed-in demo devices.':'Simulated readings stopped.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _showDemoPassword(String password)async{await showDialog<void>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(title:const Text('Save your Guided Demo password'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('This generated password is shown only once. Keep it available for authenticator setup and phone pairing.'),const SizedBox(height:12),SelectableText(password)]),actions:[TextButton(onPressed:()=>Clipboard.setData(ClipboardData(text:password)),child:const Text('Copy password')),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Continue'))]));}
 Future<void> _startGuidedDemo()async{
  var profile='showcase';
  final selected=await showDialog<String>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
   title:const Text('Start Guided Demo'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Showcase starts with example locations, linked sensors and alert history. Walkthrough starts with an unlinked sensor.'),
    RadioListTile<String>(value:'showcase',groupValue:profile,title:const Text('Showcase · recommended'),onChanged:(value)=>setDialogState(()=>profile=value!)),
    RadioListTile<String>(value:'walkthrough',groupValue:profile,title:const Text('Walkthrough · start empty'),onChanged:(value)=>setDialogState(()=>profile=value!)),
   ]),
   actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,profile),child:const Text('Start'))],
  )));
  if(selected==null)return;
  try{
   final d=Map<String,dynamic>.from(await request('/demo/start',method:'POST',body:{'profile':selected}));
   token=d['token'];instant=false;guided=true;await storage.write(key:'session',value:token);
   final initial=Map<String,dynamic>.from(await request('/status'));crop=(initial['crop']??'Maize').toString();
   startEvents();await refresh();await _showDemoPassword(d['demoPassword'].toString());
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
 }
 Widget _demoChecklist({bool firstRun=false}){final pending=demoSteps.where((step)=>step['part']=='B'&&step['completed']!=true).toList();final next=pending.isEmpty?null:pending.first;return Card(child:ListTile(title:Text(firstRun?'Demo guide':'Next step'),subtitle:Text(next==null?'Open the guide to review the demonstration.':next['title'].toString()),trailing:const Icon(Icons.chevron_right),onTap:_showDemoGuide));}
 Future<void> _setDemoStep(int step,bool completed)async{try{await request('/demo/checklist/$step',method:'PATCH',body:{'completed':completed});await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _showDemoGuide()async{
  const firstSteps=[
   {'part':'A','title':'Explore Instant Demo','where':'Overview','hint':'Explain that readings are simulated and shared without an account.'},
   {'part':'A','title':'Compare trend ranges and export readings','where':'Trends','hint':'Show 24 hours, 1 month and 3 months, then export.'},
   {'part':'A','title':'Switch crops and compare target bands','where':'Overview','hint':'Choose another crop and compare its target band.'},
   {'part':'A','title':'Review simulated alert history','where':'Alerts','hint':'Point out that SMS is not sent.'},
  ];
  final steps=guided?[...firstSteps,...demoSteps.where((step)=>step['part']=='B')]:firstSteps;
  final pending=guided?demoSteps.where((step)=>step['part']=='B'&&step['completed']!=true).toList():firstSteps;
  final next=pending.isEmpty?null:pending.first;
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(sheetContext)=>SafeArea(child:SizedBox(
   height:MediaQuery.of(sheetContext).size.height*.82,
   child:ListView(padding:const EdgeInsets.all(20),children:[
    Row(children:[const Expanded(child:Text('Demo guide',style:TextStyle(fontSize:22,fontWeight:FontWeight.w700))),IconButton(tooltip:'Close demo guide',onPressed:()=>Navigator.pop(sheetContext),icon:const Icon(Icons.close))]),
    Card(color:const Color(0xffe1f0e6),child:Padding(padding:const EdgeInsets.all(14),child:Text(next==null?'Next step: Start with the Instant Demo overview.':'Next step: ${next['title']}',style:const TextStyle(fontWeight:FontWeight.w700)))),
    for(final step in steps)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text('${step['part']??'B'} · ${step['title']}',style:const TextStyle(fontWeight:FontWeight.w700)),
     const SizedBox(height:5),Text(step['hint']?.toString()??'Follow the presenter prompt.',style:const TextStyle(color:muted)),
     if(step['expected']!=null)Text('Expected: ${step['expected']}',style:const TextStyle(color:muted)),
     if(step['completed']==true)const Text('Done',style:TextStyle(color:green,fontWeight:FontWeight.w700)),
     if(guided&&step['auto']!=true&&step['step'] is num)TextButton(onPressed:()=>_setDemoStep((step['step'] as num).toInt(),step['completed']!=true),child:Text(step['completed']==true?'Mark incomplete':'Mark complete')),
     Align(alignment:Alignment.centerLeft,child:TextButton(onPressed:(){Navigator.pop(sheetContext);final destination=step['where'];setState(()=>tab=destination=='Trends'?1:destination=='My Crops'?2:destination=='Alerts'?3:destination=='Settings'?4:0);refresh();},child:const Text('Take me there'))),
    ]))),
    if(guided)const Padding(padding:EdgeInsets.all(8),child:Text('QR failure examples: wait for expiry, scan one code twice, or enter three incorrect match numbers.',style:TextStyle(color:muted))),
   ]),
  )));
 }
 void _toggleSimulatedOffline(){setState((){simulatedOffline=!simulatedOffline;offline=simulatedOffline;});if(simulatedOffline){stopEvents();}else{startEvents();refresh(manual:true);}}
 Future<void> enterInstant()async{instant=true;token=null;entered=true;tab=0;try{final initial=Map<String,dynamic>.from(await request('/status',auth:false));crop=(initial['crop']??'Maize').toString();}catch(_){}startEvents();await refresh();}
 Future<void> auth(bool register)async{if(register&&password.text!=confirmPassword.text){setState(()=>error='Passwords do not match.');return;}setState(()=>loading=true);try{final loginBody=register?{'name':name.text,'phone':phone.text,'password':password.text}:{'phone':phone.text,'password':password.text,'totpCode':totpCode.text.trim()};final d=Map<String,dynamic>.from(await request(register?'/account/register':'/account/login',method:'POST',auth:false,body:loginBody));token=d['token'] as String;instant=false;await storage.write(key:'session',value:token);entered=true;final initial=Map<String,dynamic>.from(await request('/status'));crop=(initial['crop']??'Maize').toString();error='';needsTotp=false;totpCode.clear();startEvents();await refresh();}catch(e){final message=e.toString().replaceFirst('Exception: ','');if(message.contains('authenticator code')){needsTotp=true;}error=message;}finally{if(mounted)setState(()=>loading=false);}}
 String? get estimate{final e=data['estimate'];if(offline||data['stale']==true||e==null)return null;final r=e['rangeWeeks'];if(r is! List||r.length<2)return null;return (r[0] as num)<=0?'Less than 1 week':'About ${r[0]}–${r[1]} weeks';}
 @override
 Widget build(BuildContext context){
  if(appLocked)return _lockedScreen();
  if(!entered)return _welcome();
  final reading=data['reading'] as Map<String,dynamic>?;
  final Map<String,dynamic> bands=(data['targetBands'] as Map<String,dynamic>?) ?? <String,dynamic>{};
  final tv=(reading?['temperature'] as num?)?.toDouble(),hv=(reading?['humidity'] as num?)?.toDouble();
  return Scaffold(
   appBar:AppBar(
    leading:Padding(padding:const EdgeInsets.all(7),child:Container(width:40,height:40,padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:Image.asset('assets/brand/peo-yame-512.png'))),
    title:const Text('Peo Yame',style:TextStyle(fontWeight:FontWeight.w700)),
    actions:[Padding(padding:const EdgeInsets.only(right:10),child:Center(child:Text(guided?'Demo mode on':instant?'Demo · simulated readings':offline?'Offline':'Connected',style:const TextStyle(fontSize:11))))],
   ),
   body:RefreshIndicator(
    onRefresh:()=>refresh(manual:true),
    child:ListView(
     padding:const EdgeInsets.all(16),
     children:[
      if(instant)const _Banner('Shared demo profile · simulated readings'),
      if(guided)const _Banner('Demo session. Data is simulated and will be deleted.'),
      if(guided&&demoSessionExpiresAt!=null)_demoExpiryBanner(),
      if(offline)const _Banner('Offline. Last known values may be out of date.',warning:true),
      Text(pages[tab],style:const TextStyle(fontSize:25,fontWeight:FontWeight.w700,color:ink)),
      const SizedBox(height:24),
      if(tab==0)...[
       _statusCard(),
       Row(children:[
        Expanded(child:_Gauge(title:'Temperature',value:tv,low:bands['temperatureC']?[0],high:bands['temperatureC']?[1],unit:'°C',icon:LucideIcons.thermometer)),
        const SizedBox(width:10),
        Expanded(child:_Gauge(title:'Humidity',value:hv,low:bands['humidityPercent']?[0],high:bands['humidityPercent']?[1],unit:'%',icon:LucideIcons.droplet)),
       ]),
       if(readingCreatedAt!=null)_readingAgeCaption(),
       if(estimate!=null)_estimateCard(),
       if(data['stale']==true)_staleEstimateCard(),
       _cropCard(),
      ],
      if(tab==1)_trendScreen(),
      if(tab==2)...[_cropList(),_addCrop()],
      if(tab==3)_alertsScreen(),
      if(tab==4)(instant?_instantSettings():_settings()),
      const SizedBox(height:16),
      if(tab!=4)Text('Last synced: $lastSync',style:const TextStyle(color:muted,fontSize:12)),
     ],
    ),
   ),
   floatingActionButton:instant||guided?FloatingActionButton.extended(onPressed:_showDemoGuide,icon:const Icon(Icons.menu_book_outlined),label:const Text('Demo guide')):null,
   bottomNavigationBar:NavigationBar(
    selectedIndex:tab,
    onDestinationSelected:(i){setState(()=>tab=i);refresh();},
    destinations:const[
     NavigationDestination(icon:Icon(LucideIcons.house),label:'Overview'),
     NavigationDestination(icon:Icon(LucideIcons.chartNoAxesCombined),label:'Trends'),
     NavigationDestination(icon:Icon(LucideIcons.sprout),label:'My Crops'),
     NavigationDestination(icon:Icon(LucideIcons.bell),label:'Alerts'),
     NavigationDestination(icon:Icon(LucideIcons.settings),label:'Settings'),
    ],
   ),
  );
 }
 Widget _welcome()=>Scaffold(body:ListView(padding:const EdgeInsets.fromLTRB(24,38,24,24),children:[Center(child:Container(width:112,height:112,decoration:const BoxDecoration(color:Color(0xffe1f0e6),shape:BoxShape.circle),padding:const EdgeInsets.all(24),child:Image.asset('assets/brand/peo-yame-512.png'))),const SizedBox(height:20),Text(entryMode=='welcome'?'Welcome to\nPeo Yame':entryMode=='login'?'Sign in':entryMode=='backend'?'Connect to backend':'Create account',textAlign:TextAlign.center,style:const TextStyle(fontSize:32,height:1.2,fontWeight:FontWeight.w700,color:ink)),const SizedBox(height:8),if(entryMode=='welcome')...[
    const Text('Storage monitoring for your harvest',textAlign:TextAlign.center,style:TextStyle(color:muted,height:1.5,fontSize:16)),
    const SizedBox(height:24),
    FilledButton(onPressed:()=>setState(()=>entryMode='login'),child:const Text('Sign in')),
    TextButton(onPressed:scanPhoneQr,child:const Text('Sign in with QR code')),
    OutlinedButton(onPressed:()=>setState(()=>entryMode='register'),child:const Text('Create account')),
    TextButton(onPressed:enterInstant,child:const SizedBox(height:48,child:Center(child:Text('Demo mode')))),
    const _Banner('Instant Demo uses shared simulated readings and creates no account.'),
    if(!guidedDemoEnabled)const Text('Guided Demo is off. On the computer, open the Peo Yame tray menu and choose Demo mode.',style:TextStyle(color:muted)),
  ]else if(entryMode=='backend')...[
    const _Banner('Connect to a trusted Peo Yame backend. The address stays masked until you choose to reveal it.'),
    _backendConnectionPanel(),
    TextButton(onPressed:()=>setState(()=>entryMode='welcome'),child:const Text('Back')),
  ]else...[
    if(entryMode=='register')_field('Name',name),
    _field('Botswana phone',phone),
    _field('Password',password,secret:true),
    if(entryMode=='login'&&needsTotp)_field('Authenticator code',totpCode),
    if(entryMode=='register')_field('Confirm password',confirmPassword,secret:true),
    if(entryMode=='login')TextButton(onPressed:scanPhoneQr,child:const Text('Sign in with QR code')),
    if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.red)),
    FilledButton(onPressed:loading?null:()=>auth(entryMode=='register'),child:Text(entryMode=='register'?'Create account':'Sign in')),
    TextButton(onPressed:()=>setState((){entryMode='welcome';error='';}),child:const Text('Back')),
  ]]));
 Widget _field(String label,TextEditingController c,{bool secret=false,Widget? suffix})=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:TextField(controller:c,obscureText:secret,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),suffixIcon:suffix)));
 Widget _statusCard(){final outside=data['statusLabel']=='Outside target band',color=outside?statusWarning:statusGreen;return Card(color:outside?statusWarningBg:statusGreenBg,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(outside?LucideIcons.triangleAlert:LucideIcons.circleCheck,color:color),const SizedBox(width:8),Expanded(child:Text((data['statusLabel']??'No readings').toString(),style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:color)))]),const SizedBox(height:7),const Text('This compares the latest reading with the target band for this crop. It does not check the crop itself.',style:TextStyle(color:muted)),if(guided&&demoSimulationActive)const Padding(padding:EdgeInsets.only(top:8),child:Text('Simulated readings update every 3 seconds across signed-in demo devices.',style:TextStyle(color:muted)))])));}
 Widget _demoExpiryBanner(){final seconds=max(0,demoSessionExpiresAt!.difference(DateTime.now()).inSeconds).toInt(),minutes=seconds~/60;final text=seconds==0?'Guided Demo session expired':minutes>=60?'Guided Demo expires in ${minutes~/60}h ${minutes%60}m':'Guided Demo expires in $minutes:${(seconds%60).toString().padLeft(2,'0')}';return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[_Banner(seconds>0&&seconds<=600?'$text · Reset and start again if you need more time.':text,warning:seconds<=600),if(seconds>0&&seconds<=600)Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:_resetGuidedDemo,icon:const Icon(Icons.restart_alt),label:const Text('Reset and start again')))]);}
 Future<void> _resetGuidedDemo()async{try{await request('/demo/reset',method:'POST');}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));return;}await signOut();}
 String get presenterLanAddress{if(detectedLanAddress==null)return preflightLoading?'Checking…':'Not detected';final uri=Uri.tryParse(detectedLanAddress!);final host=uri?.host??'';if(host=='localhost'||host=='::1'||host.startsWith('127.'))return 'Not detected';return showLanAddress?detectedLanAddress!:maskedBackendAddress(detectedLanAddress);}
 Widget _presenterPreflight()=>_settingsSection('Before you present','Status reported by this app and backend; phone reachability cannot be confirmed here.',Icons.checklist,[
  Text(guidedDemoEnabled?'Demo mode is on':'Demo mode is off',style:const TextStyle(fontWeight:FontWeight.w700)),
  Text(guided?'Simulated readings: ${demoSimulationActive?'running every 3 seconds':'paused'}':'Simulated readings: no Guided Demo session'),
  Text(guided?'Active sessions for this demo user: ${preflightLoading?'Checking…':presenterSessions.length}':'Active sessions for this demo user: Not applicable'),
  Text('Detected LAN address: $presenterLanAddress'),
  if(detectedLanAddress!=null&&presenterLanAddress!='Not detected')TextButton(onPressed:()=>setState(()=>showLanAddress=!showLanAddress),child:Text(showLanAddress?'Hide LAN address':'Show LAN address')),
  if(preflightError!=null)Text('Preflight could not load: $preflightError',style:const TextStyle(color:Color(0xffb3382c))),
  const Text('Use the same Wi-Fi on both devices. Allow the Windows Firewall prompt. Plain HTTP is for a controlled network only.',style:TextStyle(color:muted)),
  const Text('Phone reachability: Not verified from the backend.',style:TextStyle(color:muted)),
  TextButton.icon(onPressed:()async{await _loadPresenterPreflight(force:true);if(mounted)setState((){});},icon:const Icon(Icons.refresh),label:const Text('Refresh presenter checks')),
 ]);
 Widget _readingAgeCaption(){final seconds=max(0,DateTime.now().difference(readingCreatedAt!).inSeconds).toInt();return Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Expanded(child:Text(readingAgeCaption(seconds),style:TextStyle(color:seconds>60?statusWarning:muted))),if(seconds>60&&guided)TextButton(onPressed:_toggleDemoSimulation,child:const Text('Start simulated readings'))]));}
 Widget _staleEstimateCard()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Estimate hidden: the latest reading is more than 15 minutes old.',style:TextStyle(fontWeight:FontWeight.w700)),if(guided)TextButton(onPressed:_toggleDemoSimulation,child:const Text('Start simulated readings'))else const Text('The estimate appears again when a recent simulated reading is available.',style:TextStyle(color:muted))])));
 String get inspectionSummary{final match=sites.where((s)=>s['id']==inspectionSiteId).toList();if(match.isEmpty)return 'Choose a storage location to record a manual crop check.';final s=match.first,last=s['lastInspectedAt'];return '${s['inspectionPrompt']} · Last checked: ${last==null?'Not recorded':DateTime.parse(last).toLocal()}';}
 Future<void> _chooseInspectionSite()async{if(sites.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add a storage location before recording a crop check.')));return;}final selected=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('Where did you check your crop?')),for(final s in sites)ListTile(title:Text('${s['name']} · ${s['crop']}'),subtitle:Text(s['inspectionPrompt']??'Manual crop check due'),onTap:()=>Navigator.pop(c,s['id'] as String))])));if(selected!=null)await _markInspection(selected);}
 Future<void> _markInspection(String siteId)async{try{final result=Map<String,dynamic>.from(await request('/sites/$siteId/inspection',method:'POST'));inspectionSiteId=siteId;await refresh();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['inspectionPrompt']=='Check your crop now'?'Inspection recorded. Conditions remain outside the target band; check your crop now.':'Inspection recorded. Your next manual check is due in 3 days.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Widget _estimateCard(){final estimateData=data['estimate'] as Map<String,dynamic>?,risk=estimateData?['risk']?.toString()??'Unknown',riskColor=risk=='High'?statusDanger:risk=='Medium'?statusWarning:statusGreen,riskBackground=risk=='High'?statusDangerBg:risk=='Medium'?statusWarningBg:statusGreenBg;return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Expanded(child:Text('Rough storage estimate',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700))),_Tag('Estimate')]),const SizedBox(height:9),Text(estimate!,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700,color:darkGreen)),if(estimateData!=null)Padding(padding:const EdgeInsets.only(top:6),child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:riskBackground,borderRadius:BorderRadius.circular(20)),child:Text('Rough risk: $risk',style:TextStyle(color:riskColor,fontWeight:FontWeight.w700)))),const SizedBox(height:6),Text(instant?'Demo estimate from simulated readings. A rough guess from temperature and humidity only. It does not inspect your crop. Check your crops by hand every few days.':'A rough guess from temperature and humidity only. It does not inspect your crop. Check your crops by hand every few days.',style:const TextStyle(height:1.45,color:muted)),if(!instant)Text(inspectionSummary,style:const TextStyle(fontSize:12,color:muted)),if(!instant)TextButton(onPressed:_chooseInspectionSite,child:const Text('I checked my crop')),TextButton(onPressed:()=>showModalBottomSheet(context:context,builder:(_)=>const Padding(padding:EdgeInsets.all(24),child:Text('This unvalidated estimate uses temperature and humidity target bands only. It ignores crop moisture, variety, maturity, pests, packaging, ventilation and time already stored. Check your crops by hand.'))),child:const Text('How is this estimated?'))])));}
 Widget _cropCard()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Selected crop',style:TextStyle(fontWeight:FontWeight.w700)),DropdownButton<String>(isExpanded:true,value:catalog.any((item)=>item['name']==crop)?crop:null,items:catalog.map((item)=>DropdownMenuItem<String>(value:item['name'].toString(),child:Text(item['name'].toString()))).toList(),onChanged:(v){if(v!=null)_selectCrop(v);})])));
 Future<void> _selectCrop(String value)async{setState(()=>crop=value);try{await request('/crop-selection',method:'POST',body:{'crop':value});await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _addCustomCrop()async{
  final nameController=TextEditingController(),tMin=TextEditingController(text:'10'),tMax=TextEditingController(text:'25'),hMin=TextEditingController(text:'45'),hMax=TextEditingController(text:'70'),baseline=TextEditingController(text:'8');
  var category='crop';
  final accepted=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
   title:const Text('Add crop to monitor'),
   content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:nameController,decoration:const InputDecoration(labelText:'Item name')),
    DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Category'),items:const[DropdownMenuItem(value:'crop',child:Text('Crop')),DropdownMenuItem(value:'fruit',child:Text('Fruit')),DropdownMenuItem(value:'vegetable',child:Text('Vegetable'))],onChanged:(value){if(value!=null)setDialogState(()=>category=value);}),
    Row(children:[Expanded(child:TextField(controller:tMin,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Temp low °C'))),const SizedBox(width:8),Expanded(child:TextField(controller:tMax,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Temp high °C')))]),
    Row(children:[Expanded(child:TextField(controller:hMin,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Humidity low %'))),const SizedBox(width:8),Expanded(child:TextField(controller:hMax,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Humidity high %')))]),
    TextField(controller:baseline,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Rough estimate baseline (weeks)')),
   ])),
   actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Save item'))],
  )));
  if(accepted==true){
   try{
    final name=nameController.text.trim();
    await request('/crops',method:'POST',body:{'name':name,'category':category,'temperatureMin':double.parse(tMin.text),'temperatureMax':double.parse(tMax.text),'humidityMin':double.parse(hMin.text),'humidityMax':double.parse(hMax.text),'baselineWeeks':int.parse(baseline.text)});
    setState(()=>crop=name);
    await request('/crop-selection',method:'POST',body:{'crop':name});
    await refresh();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Item added to your catalog and selected.')));
   }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  for(final c in [nameController,tMin,tMax,hMin,hMax,baseline]){c.dispose();}
 }
 Widget _trendScreen(){final bands=data['targetBands'] as Map<String,dynamic>? ?? <String,dynamic>{};final tb=(bands['temperatureC'] as List?)?.cast<num>()??const <num>[12,25],hb=(bands['humidityPercent'] as List?)?.cast<num>()??const <num>[50,70];final label=trendRange=='24h'?'24 hours':trendRange=='month'?'1 month':'3 months';return Column(children:[Wrap(spacing:4,children:[for(final range in ['24h','month','3months'])ChoiceChip(label:Text(range=='24h'?'24 hours':range=='month'?'1 month':'3 months'),selected:trendRange==range,onSelected:(_){setState(()=>trendRange=range);refresh();})]),Wrap(spacing:8,children:[OutlinedButton(onPressed:()=>_exportReadings('csv'),child:const Text('Copy CSV')),OutlinedButton(onPressed:()=>_exportReadings('markdown'),child:const Text('Copy Markdown'))]),_TrendChart(title:'Temperature',unit:'°C',range:label,count:trendCount,summary:trendSummary['temperature'] as Map<String,dynamic>?,points:trends,field:'temperature',band:tb,color:green),_TrendChart(title:'Humidity',unit:'%',range:label,count:trendCount,summary:trendSummary['humidity'] as Map<String,dynamic>?,points:trends,field:'humidity',band:hb,color:const Color(0xff2f5fbf))]);}
 Future<void> _exportReadings(String format)async{try{final headers={'authorization':'Bearer '+(token??'')};final response=await http.get(url('/readings/export?format=$format'),headers:headers).timeout(const Duration(seconds:10));if(response.statusCode<200||response.statusCode>=300)throw Exception('Could not export readings.');await Clipboard.setData(ClipboardData(text:response.body));if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$format readings copied to clipboard.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Widget _cropList(){if(instant)return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('My Crops needs an account',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('Instant Demo is read-only. Add storage locations, link sensors and manage crops in Guided Demo.',style:TextStyle(color:muted)),if(guidedDemoEnabled)TextButton(onPressed:_startGuidedDemo,child:const Text('Start Guided Demo to try this'))])));final linked=sensors.where((x)=>x['siteId']!=null).length,online=sensors.where((x)=>x['online']==true).length;return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[if(guided&&sites.isEmpty)_demoChecklist(firstRun:true),Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text('${sites.length} storage locations · $linked sensors linked · $online online',style:const TextStyle(color:muted))),for(final s in sites)Card(child:Column(children:[ListTile(title:Text(s['name']??''),subtitle:Text('${s['crop']} · Account data'),trailing:IconButton(tooltip:'Delete location',onPressed:()=>request('/sites/${s['id']}',method:'DELETE').then((_)=>refresh()),icon:const Icon(LucideIcons.trash2))),if(s['estimate'] is Map<String,dynamic>)_siteEstimate(s['estimate'] as Map<String,dynamic>),Padding(padding:const EdgeInsets.fromLTRB(16,0,16,8),child:Row(children:[Expanded(child:Text('${s['inspectionPrompt']} · Last checked: ${s['lastInspectedAt']==null?'Not recorded':DateTime.parse(s['lastInspectedAt']).toLocal()}',style:const TextStyle(fontSize:12,color:muted))),TextButton(onPressed:()=>_markInspection(s['id'].toString()),child:const Text('I checked my crop'))])),for(final sensor in sensors.where((x)=>x['siteId']==s['id']))ListTile(dense:true,leading:Icon(sensor['online']==true?LucideIcons.circleCheck:LucideIcons.triangleAlert,color:sensor['online']==true?green:muted),title:Text(sensor['externalId']??'Sensor'),subtitle:Text('${sensor['status']}${sensor['synthetic']==true?' · simulated':''}'),trailing:TextButton(onPressed:()=>_unlinkSensor(sensor['id'].toString()),child:const Text('Unlink'))),if(sensors.any((x)=>x['siteId']==null))TextButton(onPressed:()=>_chooseSensorForSite(s['id'].toString()),child:const Text('Link available sensor'))]))]);}
 Widget _siteEstimate(Map<String,dynamic> estimate){final range=estimate['rangeWeeks'] as List,risk=estimate['risk']?.toString()??'Unknown',riskColor=risk=='High'?statusDanger:risk=='Medium'?statusWarning:statusGreen,riskBackground=risk=='High'?statusDangerBg:risk=='Medium'?statusWarningBg:statusGreenBg;final rangeText=(range[0] as num)<=0?'Less than 1 week':'About ${range[0]}–${range[1]} weeks';return Padding(padding:const EdgeInsets.fromLTRB(16,0,16,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:8,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[Text('Rough storage estimate · $rangeText',style:const TextStyle(fontWeight:FontWeight.w600)),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:riskBackground,borderRadius:BorderRadius.circular(20)),child:Text('Rough risk: $risk',style:TextStyle(color:riskColor,fontWeight:FontWeight.w700)))]),Text(estimate['disclaimer']?.toString()??'A rough guess from temperature and humidity only. It does not inspect your crop. Check your crops by hand every few days.',style:const TextStyle(color:muted,fontSize:12))]));}
 Future<void> _chooseSensorForSite(String siteId)async{final available=sensors.where((x)=>x['siteId']==null).toList();if(available.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Register a sensor first.')));return;}final selected=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('Choose a sensor to link')),for(final sensor in available)ListTile(title:Text(sensor['externalId']??''),subtitle:Text(sensor['status']??'Offline'),onTap:()=>Navigator.pop(c,sensor['id'] as String))])));if(selected==null)return;try{await request('/sensors/$selected/link',method:'POST',body:{'siteId':siteId});await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _unlinkSensor(String id)async{try{await request('/sensors/$id/link',method:'DELETE');await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Future<void> _registerSensor()async{try{await request('/sensors',method:'POST',body:{'externalId':sensorId.text});sensorId.clear();await refresh();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Widget _addCrop()=>instant?const SizedBox.shrink():Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[_field('Location name',siteName),FilledButton(onPressed:()=>request('/sites',method:'POST',body:{'name':siteName.text,'crop':crop}).then((_){siteName.clear();return refresh();}),child:const Text('Add storage location')),const Divider(),OutlinedButton(onPressed:_addCustomCrop,child:const Text('Add crop to monitor')),const Divider(),_field('Register sensor ID',sensorId),OutlinedButton(onPressed:_registerSensor,child:const Text('Register sensor'))])));
 Widget _alertsScreen()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const _Banner('Simulated alert log. SMS is not sent.'),if(alerts.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.check_circle_outline,color:green,size:32),SizedBox(height:10),Text('No alerts yet',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700)),Text('Simulated readings are within the selected crop target band.',style:TextStyle(color:muted))]))),for(final a in alerts)Card(child:Column(children:[ListTile(leading:Icon(a['reviewed']==1?Icons.check_circle_outline:Icons.warning_amber_outlined,color:a['reviewed']==1?green:const Color(0xff8a6516)),title:Text(a['message']??''),subtitle:Text('${a['created_at']??''} · simulated · ${a['reviewed']==1?'reviewed':'needs review'}'),trailing:a['reviewed']==1?null:instant?TextButton(onPressed:_startGuidedDemo,child:const Text('Try in Guided Demo')):TextButton(onPressed:()=>request('/alerts/${a['id']}',method:'PATCH').then((_)=>refresh()),child:const Text('Mark reviewed'))),if(a['estimate'] is Map<String,dynamic>)_siteEstimate(a['estimate'] as Map<String,dynamic>)]))]);
 Future<String?> _manualQrCode()async{final field=TextEditingController();try{final typed=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Manual sign-in setup'),content:TextField(controller:field,decoration:const InputDecoration(labelText:'Backend address or pairing code')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,field.text.trim()),child:const Text('Continue'))]));if(typed==null||typed.isEmpty)return null;final uri=Uri.tryParse(typed);if(uri!=null&&(uri.scheme=='http'||uri.scheme=='https')&&uri.hasAuthority)return jsonEncode({'flow':'backend','baseUrl':typed});return typed;}finally{field.dispose();}}
 Future<String?> openScanner()async{if(manualQrEntry){manualQrEntry=false;return _manualQrCode();}final controller=MobileScannerController();var popped=false;try{return await showDialog<String>(context:context,barrierDismissible:false,builder:(ctx)=>Scaffold(backgroundColor:const Color(0xff0b1410),appBar:AppBar(title:const Text('Scan sign-in code'),leading:IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(LucideIcons.x))),body:Column(children:[const Padding(padding:EdgeInsets.all(20),child:Text('Place the QR code inside the frame. Codes expire after 90 seconds and work once.',style:TextStyle(color:Colors.white))),Expanded(child:Center(child:SizedBox(width:280,height:280,child:MobileScanner(controller:controller,onDetect:(capture){for(final item in capture.barcodes){final value=item.rawValue;if(value!=null&&value.isNotEmpty&&!popped){popped=true;Navigator.pop(ctx,value);break;}}})))),TextButton(onPressed:()async{final typed=await _manualQrCode();if(typed!=null&&typed.isNotEmpty)Navigator.pop(ctx,typed);},child:const Text('Enter address or pairing code manually')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel'))])));}finally{await controller.dispose();}}
bool privateBackend(Uri u)=>isPrivateBackendUrl(u);
Future<bool> cameraRationale()async{final choice=await showDialog<int>(context:context,builder:(c)=>AlertDialog(title:const Text('Why camera access?'),content:const Text('We use the camera only to scan a Peo Yame sign-in or backend connection code.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,0),child:const Text('Not now')),TextButton(onPressed:()=>Navigator.pop(c,1),child:const Text('Enter address or pairing code manually')),FilledButton(onPressed:()=>Navigator.pop(c,2),child:const Text('Continue'))]));if(choice==1){manualQrEntry=true;return true;}if(choice!=2)return false;PermissionStatus permission;try{permission=await Permission.camera.request();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));return false;}if(permission.isGranted)return true;final recovery=await showDialog<int>(context:context,builder:(c)=>AlertDialog(title:const Text('Camera access was denied'),content:const Text('Allow camera access in Settings, or enter an address or pairing code manually.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,0),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(c,1),child:const Text('Enter address or pairing code manually')),FilledButton(onPressed:()=>Navigator.pop(c,2),child:const Text('Open settings'))]));if(recovery==1){manualQrEntry=true;return true;}if(recovery==2){try{await openAppSettings();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}return false;}
Future<bool> _confirmBackendSwitch(Uri remote)async{
 var revealAddress=false;
 final accepted=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
  title:const Text('Connect to this backend?'),
  content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
   const Text('Use only a backend you trust. Switching backends signs you out.'),
   const SizedBox(height:8),
   Text(revealAddress?'Backend address: ${remote.authority}':'Backend address hidden'),
   TextButton(onPressed:()=>setDialogState(()=>revealAddress=!revealAddress),child:Text(revealAddress?'Hide address':'Show address')),
  ]),
  actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Connect'))],
 )));
 return accepted??false;
}
Future<void> _connectBackend(String raw)async{try{final remote=Uri.parse(raw.trim());if(!remote.hasAuthority||remote.userInfo.isNotEmpty||!privateBackend(remote))throw Exception('Use a private-network HTTP address or a secure HTTPS backend without URL credentials.');final value='${remote.scheme}://${remote.authority}';if(value!=savedBackend){if(await _confirmBackendSwitch(remote)!=true){address.text=savedBackend;return;}if(token!=null)await signOut();else await storage.delete(key:'session');token=null;address.text=value;}await _checkAndSaveBackend();if(mounted&&!entered){setState(()=>entryMode='login');ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Backend connected. Sign in to continue.')));}}catch(e){address.text=savedBackend;if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
Future<void> _scanBackendQr()async{if(!await cameraRationale())return;final raw=await openScanner();if(raw==null)return;try{final payload=Map<String,dynamic>.from(jsonDecode(raw) as Map);if(payload['flow']!='backend')throw Exception('This is not a backend connection QR code.');await _connectBackend(payload['baseUrl'].toString());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
Future<void> _saveBackendAddress()async=>_connectBackend(address.text);
Future<void> _checkAndSaveBackend()async{final base=address.text.trim().replaceAll(RegExp(r'/+$'),'');final response=await http.get(Uri.parse('$base/api/health')).timeout(const Duration(seconds:8));if(response.statusCode!=200)throw Exception('This address did not respond as a Peo Yame backend.');final result=Map<String,dynamic>.from(jsonDecode(response.body) as Map);if(result['authEnabled']!=true)throw Exception('This backend does not have accounts enabled.');await storage.write(key:'backend',value:base);savedBackend=base;if(mounted)setState(()=>backendStatus='Connected · accounts enabled · checked just now');}
Widget _backendConnectionPanel()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:_field('Backend address',address,secret:!showBackendAddress,suffix:IconButton(tooltip:showBackendAddress?'Hide address':'Show address',onPressed:()=>setState(()=>showBackendAddress=!showBackendAddress),icon:Icon(showBackendAddress?Icons.visibility_off:Icons.visibility)))),
Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Text(backendStatus,style:const TextStyle(color:muted))),
Wrap(children:[
 TextButton.icon(onPressed:_saveBackendAddress,icon:const Icon(Icons.check_circle_outline),label:const Text('Save and check')),
 TextButton.icon(onPressed:_scanBackendQr,icon:const Icon(Icons.qr_code_scanner),label:const Text('Scan backend QR')),
]),
]);
Future<void> scanPhoneQr()async{
 if(!await cameraRationale())return;
 final raw=await openScanner();if(raw==null)return;
 try{
  Map<String,dynamic> payload;
  try{payload=Map<String,dynamic>.from(jsonDecode(raw) as Map);}catch(_){payload={'baseUrl':savedBackend,'codeId':raw,'flow':'phone'};}
  if(payload['flow']=='backend'){await _connectBackend(payload['baseUrl'].toString());return;}
  if(payload['flow']!='phone')throw Exception('This is not a phone sign-in code. Use Settings to connect to a backend, or enter its address in the manual entry dialog.');
  final remote=Uri.parse(payload['baseUrl'].toString());
  if(!privateBackend(remote))throw Exception('This QR must use a private-network backend.');
  final value='${remote.scheme}://${remote.authority}';
  if(value!=savedBackend){
   if(await _confirmBackendSwitch(remote)!=true)return;
   if(token!=null)await signOut();else await storage.delete(key:'session');
   token=null;address.text=value;await _checkAndSaveBackend();
  }
  final codeId=payload['codeId'].toString();
  final verifier=base64UrlEncode(List<int>.generate(32,(_)=>Random.secure().nextInt(256)));
  final verifierHash=sha256.convert(utf8.encode(verifier)).toString();
  final claim=Map<String,dynamic>.from(await request('/qr/phone/claim',method:'POST',auth:false,body:{'codeId':codeId,'verifierHash':verifierHash,'name':'Peo Yame Android','version':'1'}));
  final approved=await waitForApproval(codeId,verifier,claim['matchCode'].toString(),claim['expiresAt'].toString());
  if(!approved)return;
  final session=Map<String,dynamic>.from(await request('/qr/phone/redeem',method:'POST',auth:false,body:{'codeId':codeId,'verifier':verifier}));
  token=session['token'];instant=false;guided=session['isDemo']==true;entered=true;
  await storage.write(key:'session',value:token);await refresh();
 }catch(e){address.text=savedBackend;if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
}
Future<bool> waitForApproval(String codeId,String verifier,String match,String expiry)async{
 final expires=DateTime.tryParse(expiry)??DateTime.now().add(const Duration(seconds:90));
 final seconds=ValueNotifier<int>(max(0,expires.difference(DateTime.now()).inSeconds).toInt());
 final done=Completer<bool>();
 final ticker=Timer.periodic(const Duration(seconds:1),(_)=>seconds.value=max(0,expires.difference(DateTime.now()).inSeconds).toInt());
 showDialog<void>(context:context,barrierDismissible:false,builder:(dialogContext)=>AlertDialog(
  title:const Text('Approve on your computer'),
  content:Column(mainAxisSize:MainAxisSize.min,children:[
   Text(match,style:const TextStyle(fontSize:56,fontWeight:FontWeight.w700,color:darkGreen)),
   const Text('Enter this number on your computer.'),
   const SizedBox(height:8),
   ValueListenableBuilder<int>(valueListenable:seconds,builder:(_,value,__)=>Text('Expires in ${value~/60}:${(value%60).toString().padLeft(2,'0')}'))
  ]),
  actions:[TextButton(onPressed:()async{
   try{await request('/qr/phone/withdraw',method:'POST',auth:false,body:{'codeId':codeId,'verifier':verifier});}
   catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
   if(dialogContext.mounted&&Navigator.canPop(dialogContext))Navigator.pop(dialogContext);
   if(!done.isCompleted)done.complete(false);
  },child:const Text('Cancel'))]));
 unawaited(()async{
  while(DateTime.now().isBefore(expires)&&!done.isCompleted){
   await Future<void>.delayed(const Duration(seconds:1));
   try{
    final state=Map<String,dynamic>.from(await request('/qr/phone/status?codeId='+Uri.encodeComponent(codeId)+'&verifier='+Uri.encodeComponent(verifier),auth:false));
    final value=state['state'];
    if(value=='approved'||value=='denied'||value=='cancelled'||value=='expired'){
     if(mounted&&Navigator.canPop(context))Navigator.pop(context);
     if(!done.isCompleted)done.complete(value=='approved');
     return;
    }
   }catch(_){}
  }
  if(!done.isCompleted){
   if(mounted&&Navigator.canPop(context))Navigator.pop(context);
   done.complete(false);
  }
 }());
 try{return await done.future;}finally{ticker.cancel();seconds.dispose();}
}
Future<String?> _askForPassword(String title)async{final controller=TextEditingController();try{return await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:TextField(controller:controller,obscureText:true,decoration:const InputDecoration(labelText:'Password')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('Continue'))]));}finally{controller.dispose();}}
Future<void> authenticatorFlow()async{try{final s=Map<String,dynamic>.from(await request('/authenticator/status'));if(s['enabled']==true){final pw=TextEditingController(),code=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Turn off authenticator'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:pw,obscureText:true,decoration:const InputDecoration(labelText:'Password')),TextField(controller:code,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'6-digit code'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Turn off'))]));if(ok!=true)return;final changed=Map<String,dynamic>.from(await request('/authenticator/disable',method:'POST',body:{'password':pw.text,'code':code.text.trim()}));if(changed['token'] is String){token=changed['token'] as String;await storage.write(key:'session',value:token);}if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Authenticator turned off.')));}else{final password=await _askForPassword('Re-enter your password to set up the authenticator.');if(password==null||password.isEmpty)return;final setup=Map<String,dynamic>.from(await request('/authenticator/setup',method:'POST',body:{'password':password}));if(!mounted)return;final code=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Set up authenticator'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Add this setup key to your authenticator app, then enter the 6-digit code it shows:'),SelectableText(setup['secret'].toString(),style:const TextStyle(fontWeight:FontWeight.w700,fontSize:18)),TextField(controller:code,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'6-digit code'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Turn on'))]));if(ok!=true)return;final changed=Map<String,dynamic>.from(await request('/authenticator/enable',method:'POST',body:{'code':code.text.trim()}));if(changed['token'] is String){token=changed['token'] as String;await storage.write(key:'session',value:token);}if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Authenticator is on. Sign-in will now ask for a code.')));}}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}}
Future<void> approveWeb(String codeId)async{
 final info=Map<String,dynamic>.from(await request('/qr/web/scan',method:'POST',body:{'codeId':codeId,'deviceName':'Peo Yame Android'}));
 while(true){
  final match=TextEditingController();var showNetworkAddress=false;
  final approve=await showModalBottomSheet<bool>(context:context,isScrollControlled:true,builder:(c)=>StatefulBuilder(builder:(c,setSheetState)=>Padding(
   padding:EdgeInsets.fromLTRB(24,20,24,MediaQuery.of(c).viewInsets.bottom+24),
   child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Approve sign-in on computer?',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),
    Text('Browser: ${info['browser']??'Web browser'}'),
    Text(showNetworkAddress?'Network address: ${info['address']??'Computer'}':'Network address: ${partialNetworkAddress(info['address'])}'),
    TextButton(onPressed:()=>setSheetState(()=>showNetworkAddress=!showNetworkAddress),child:Text(showNetworkAddress?'Hide network address':'Show network address')),
    TextField(controller:match,keyboardType:TextInputType.number,maxLength:2,decoration:const InputDecoration(labelText:'Enter the number shown on your computer')),
    const _Banner('Only approve if you started this sign-in just now. Never approve a request someone sent you.'),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Approve')),
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Deny')),
   ]),
  )));
  if(approve!=true){match.dispose();await request('/qr/web/deny',method:'POST',body:{'codeId':codeId});return;}
  final supported=await deviceAuth.isDeviceSupported();
  if(!supported){match.dispose();throw Exception('Device lock is not set up on this phone, so this approval cannot be confirmed.');}
  final unlocked=await deviceAuth.authenticate(localizedReason:'Confirm this computer sign-in',biometricOnly:false);
  if(!unlocked){match.dispose();throw Exception('Device confirmation was not completed.');}
  try{
   await request('/qr/web/approve',method:'POST',body:{'codeId':codeId,'matchCode':match.text.trim()});
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Computer sign-in approved.')));
   match.dispose();return;
  }catch(e){
   final message=e.toString().replaceFirst('Exception: ','');
   if(message.contains('tries left')){match.dispose();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));continue;}
   match.dispose();rethrow;
  }
 }
}
Future<void> scanWebQr()async{if(!await cameraRationale())return;final raw=await openScanner();if(raw==null)return;try{Map<String,dynamic> payload;try{payload=Map<String,dynamic>.from(jsonDecode(raw) as Map);}catch(_){payload={'baseUrl':savedBackend,'codeId':raw,'flow':'web'};}if(payload['flow']!='web')throw Exception('This QR is not a computer sign-in code.');if(token==null)throw Exception('Sign in on this phone before approving a computer.');final remote=Uri.parse(payload['baseUrl'].toString());if(!privateBackend(remote))throw Exception('This code must use a private-network backend.');final local=Uri.parse(savedBackend);if(remote.scheme+'://'+remote.authority!=local.scheme+'://'+local.authority)throw Exception('This code is from a different backend. Connect this phone to it and sign in first.');await approveWeb(payload['codeId'].toString());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
Widget _settingsSection(String title,String subtitle,IconData icon,List<Widget> children)=>Card(
 child:Padding(
  padding:const EdgeInsets.fromLTRB(16,8,16,16),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   ListTile(
    contentPadding:EdgeInsets.zero,
    leading:Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xffe1f0e6),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:green)),
    title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),
    subtitle:Text(subtitle,style:const TextStyle(color:muted)),
   ),
   const Divider(height:20),
   ...children,
  ]),
 ),
);
Widget _settingsAction(String title,String subtitle,IconData icon,VoidCallback onTap)=>ListTile(contentPadding:EdgeInsets.zero,minLeadingWidth:24,leading:Icon(icon,color:green),title:Text(title),subtitle:Text(subtitle,style:const TextStyle(color:muted)),trailing:const Icon(Icons.chevron_right),onTap:onTap);
Widget _instantSettings()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 _settingsSection('Data and sync','Shared simulated readings. Instant Demo is read-only.',Icons.sync,[
  Text('Last synced: $lastSync',style:const TextStyle(color:muted)),
  SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>refresh(manual:true),icon:const Icon(Icons.refresh),label:const Text('Refresh demo data'))),
  Wrap(spacing:8,children:[
   OutlinedButton.icon(onPressed:()=>_exportReadings('csv'),icon:const Icon(Icons.copy),label:const Text('Copy CSV')),
   OutlinedButton.icon(onPressed:()=>_exportReadings('markdown'),icon:const Icon(Icons.copy),label:const Text('Copy Markdown')),
  ]),
 ]),
 _settingsSection('Account features','Storage management, alert review, authenticator and QR pairing need Guided Demo or an account.',Icons.lock_outline,[
  if(guidedDemoEnabled)SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_startGuidedDemo,icon:const Icon(Icons.play_arrow),label:const Text('Start Guided Demo'))),
  if(!guidedDemoEnabled)const Text('Guided Demo is off. On the computer, open the Peo Yame tray menu and choose Demo mode.',style:TextStyle(color:muted)),
 ]),
 _settingsSection('Backend connection','The address is masked by default. HTTP is for a controlled demo Wi-Fi network only.',Icons.dns_outlined,[
  _backendConnectionPanel(),
 ]),
 _presenterPreflight(),
 SizedBox(width:double.infinity,child:TextButton.icon(onPressed:(){stopEvents();setState((){entered=false;instant=false;});},icon:const Icon(Icons.logout),label:const Text('Leave Demo mode'))),
]);
Widget _settings()=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 _settingsSection('Data and sync',guided&&demoSimulationActive?'Guided Demo sends a new reading every 3 seconds across signed-in devices.':'Readings update automatically across signed-in devices.',Icons.sync,[
  Text('Last synced: $lastSync',style:const TextStyle(color:muted)),
  const SizedBox(height:10),
  SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>refresh(manual:true),icon:const Icon(Icons.refresh),label:Text(instant||guided?'Refresh demo data':'Refresh data now'))),
  const Padding(padding:EdgeInsets.only(top:10),child:Text('Copy a readings export to your clipboard:',style:TextStyle(color:muted))),
  Wrap(spacing:8,runSpacing:4,children:[
   OutlinedButton.icon(onPressed:()=>_exportReadings('csv'),icon:const Icon(Icons.copy),label:const Text('Copy CSV')),
   OutlinedButton.icon(onPressed:()=>_exportReadings('markdown'),icon:const Icon(Icons.copy),label:const Text('Copy Markdown')),
  ]),
 ]),
 _settingsSection('Account and security','Manage your profile, sign-in protection, and sessions.',Icons.security,[
  _settingsAction('Profile','View your account details',Icons.person_outline,()=>request('/account').then((a)=>showDialog(context:context,builder:(_)=>AlertDialog(content:Text('${a['name']} · ${formatPhone(a['phone'])}'))))),
  _settingsAction('Authenticator app','Manage sign-in verification',Icons.verified_user_outlined,authenticatorFlow),
  _settingsAction('Active sessions','Review and revoke signed-in devices',Icons.devices,_showSessions),
  _settingsAction('Security activity','Review recent account events',Icons.history,_showSecurityActivity),
  SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Lock app with biometrics'),subtitle:const Text('Require device authentication when you return to the app.'),value:appLockEnabled,onChanged:_toggleAppLock),
 ]),
 _settingsSection('Backend connection','The address is masked by default. HTTP is for a controlled demo Wi-Fi network only.',Icons.dns_outlined,[
  _backendConnectionPanel(),
 ]),
 _settingsSection('Devices','Connect this phone to another computer using a one-time sign-in code.',Icons.devices_other,[
  SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:scanWebQr,icon:const Icon(Icons.qr_code_scanner),label:const Text('Log in on computer'))),
 ]),
 if((instant||guided)&&guidedDemoEnabled)_settingsSection('Demo tools','Practice simulated syncing, alerts, sensor, and QR flows using temporary data.',Icons.science_outlined,[
  if(guided)const Padding(padding:EdgeInsets.only(bottom:10),child:Text('Readings are simulated, not hardware measurements. QR sign-in on the other device shares this temporary profile.',style:TextStyle(color:muted))),
  if(instant)SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_startGuidedDemo,icon:const Icon(Icons.play_arrow),label:const Text('Start Guided Demo'))),
  if(guided)...[
   _demoChecklist(),
   SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_toggleDemoSimulation,icon:Icon(demoSimulationActive?Icons.stop:Icons.play_arrow),label:Text(demoSimulationActive?'Stop simulated readings':'Start simulated readings'))),
   SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Automatic breach alerts'),subtitle:const Text('Generate a simulated alert every sixth reading.'),value:autoAlerts,onChanged:(value)async{try{await request('/demo/simulation/settings',method:'POST',body:{'autoAlerts':value});setState(()=>autoAlerts=value);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}),
   Wrap(spacing:8,runSpacing:4,children:[
    OutlinedButton.icon(onPressed:()=>request('/demo/breach',method:'POST').then((_)=>refresh()),icon:const Icon(Icons.warning_amber_outlined),label:const Text('Simulate breach')),
    OutlinedButton.icon(onPressed:()=>request('/demo/simulation/in-band',method:'POST',body:{}).then((_)=>refresh()),icon:const Icon(Icons.check_circle_outline),label:const Text('Return to in-band')),
    OutlinedButton.icon(onPressed:()async{try{final list=List<dynamic>.from(await request('/sensors'));final s=list.isNotEmpty?list.first:null;if(s==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Register a sensor first to simulate readings.')));return;}await request('/demo/sensor-reading',method:'POST',body:{'sensorId':s['externalId']});await refresh();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Simulated sensor reading recorded.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}},icon:const Icon(Icons.sensors_outlined),label:const Text('Add sensor reading')),
    OutlinedButton.icon(onPressed:()=>_selectCrop(crop=='Maize'?'Sorghum':'Maize'),icon:const Icon(Icons.eco_outlined),label:const Text('Switch crop')),
    OutlinedButton.icon(onPressed:_toggleSimulatedOffline,icon:const Icon(Icons.wifi_off),label:Text(simulatedOffline?'Restore network':'Simulate network loss')),
   ]),
   TextButton.icon(onPressed:_resetGuidedDemo,icon:const Icon(Icons.delete_outline),label:const Text('Reset demo')),
  ],
 ]),
 if(instant||guided)_presenterPreflight(),
 SizedBox(width:double.infinity,child:TextButton.icon(onPressed:signOut,icon:const Icon(Icons.logout),label:const Text('Sign out'))),
]);
 Future<void> _toggleAppLock(bool enabled)async{try{if(enabled){if(!await deviceAuth.isDeviceSupported())throw Exception('Set up a device lock on this phone first.');if(!await deviceAuth.authenticate(localizedReason:'Enable biometric app lock',biometricOnly:true))return;}await storage.write(key:'appLockEnabled',value:enabled.toString());if(mounted)setState(()=>appLockEnabled=enabled);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
 Widget _lockedScreen()=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:48,color:green),const SizedBox(height:16),const Text('Peo Yame is locked',style:TextStyle(fontSize:22,fontWeight:FontWeight.w700)),const SizedBox(height:12),FilledButton(onPressed:_unlockApp,child:const Text('Unlock with biometrics'))]))));
 Future<void> _showSessions() async {
  try {
   final rows=List<Map<String,dynamic>>.from(await request('/account/sessions'));
   if(!mounted)return;
   await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    title:const Text('Active sessions'),
    content:SizedBox(width:420,child:SingleChildScrollView(
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      for(final s in rows) ListTile(
       title:Text('${s['deviceName']}${s['current']==true?' · This device':''}'),
       subtitle:Text('Signed in ${s['createdAt']} · Expires ${s['expiresAt']}'),
       trailing:s['current']==true?null:IconButton(
        tooltip:'Sign out this device',icon:const Icon(LucideIcons.logOut),
        onPressed:() async {
         try {
          await request('/account/sessions/${s['id']}',method:'DELETE');
          if(dialogContext.mounted)Navigator.pop(dialogContext);
          _showSessions();
         } catch(e) { if(mounted)setState(()=>error=e.toString()); }
        },
       ),
      ),
      const SizedBox(height:8),
      TextButton(
       onPressed:() async {
        try {
         await request('/account/sessions',method:'DELETE');
         if(dialogContext.mounted)Navigator.pop(dialogContext);
         _showSessions();
        } catch(e) { if(mounted)setState(()=>error=e.toString()); }
       },
       child:const Text('Sign out other devices'),
      ),
     ]),
    )),
   ));
  } catch(e) { if(mounted)setState(()=>error=e.toString()); }
 }
 Future<void> _showSecurityActivity() async {
  final activity=request('/account/security-activity');
  if(!mounted)return;
  await showDialog<void>(context:context,builder:(dialogContext)=>FutureBuilder<dynamic>(
   future:activity,
   builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done)return AlertDialog(
     title:const Text('Security activity'),
     content:const Row(mainAxisSize:MainAxisSize.min,children:[SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)),SizedBox(width:12),Text('Loading activity…')]),
     actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close'))],
    );
    if(snapshot.hasError)return AlertDialog(
     title:const Text('Security activity'),
     content:Text('Could not load security activity: ${snapshot.error.toString().replaceFirst('Exception: ','')}'),
     actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close'))],
    );
    final rows=List<Map<String,dynamic>>.from(snapshot.data as List);
    return AlertDialog(
     title:const Text('Security activity'),
     content:SizedBox(width:420,child:rows.isEmpty
      ? const Text('No account activity recorded.')
      : SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
       for(final item in rows) ListTile(
        title:Text(item['event'].toString().replaceAll('_',' ')),
        subtitle:Text(item['createdAt'].toString()),
       ),
      ]))),
     actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close'))],
    );
   },
  ));
 }
 Future<void> signOut()async{try{await request('/account/logout',method:'POST');}catch(_){}stopEvents();await storage.delete(key:'session');token=null;entered=false;instant=false;guided=false;appLocked=false;simulatedOffline=false;if(mounted)setState((){});}
}
class _Banner extends StatelessWidget{final String text;final bool warning;const _Banner(this.text,{this.warning=false});@override Widget build(BuildContext c)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:warning?statusWarningBg:statusGreenBg,borderRadius:BorderRadius.circular(12)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[if(warning)const Padding(padding:EdgeInsets.only(right:8,top:2),child:Icon(Icons.warning_amber_rounded,color:statusWarning,size:20)),Expanded(child:Text(text,style:TextStyle(color:warning?statusWarning:statusGreen,height:1.4,fontWeight:warning?FontWeight.w600:FontWeight.normal)))]));}
class _Tag extends StatelessWidget{final String text;const _Tag(this.text);@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xffe1f0e6),borderRadius:BorderRadius.circular(99)),child:Text(text,style:const TextStyle(color:darkGreen,fontWeight:FontWeight.w600)));}
class _Gauge extends StatelessWidget {
 final String title,unit;
 final double? value;
 final dynamic low,high;
 final IconData icon;

 const _Gauge({
  required this.title,
  required this.value,
  required this.low,
  required this.high,
  required this.unit,
  required this.icon,
 });

 @override
 Widget build(BuildContext context) {
  final lo=(low as num?)?.toDouble()??0;
  final hi=(high as num?)?.toDouble()??100;
  final position=gaugePosition(value,lo,hi,percent:unit=='%');
  final color=position.state=='In range'?statusGreen:statusDanger;
  final display=value==null?'—':unit=='%'?formatHumidity(value!):formatTemperature(value!);
  final description=value==null
   ?'No reading. Target ${lo.toStringAsFixed(0)} to ${hi.toStringAsFixed(0)} $unit.'
   :'$title $display, ${position.state.toLowerCase()}, target ${lo.toStringAsFixed(0)} to ${hi.toStringAsFixed(0)} $unit.';

  return Semantics(
   label:description,
   child:Card(
    child:Padding(
     padding:const EdgeInsets.all(10),
     child:Column(
      children:[
       Row(
        mainAxisAlignment:MainAxisAlignment.center,
        children:[
         Icon(icon,color:green,size:19),
         const SizedBox(width:6),
         Flexible(child:Text(title,style:const TextStyle(fontWeight:FontWeight.w700),overflow:TextOverflow.ellipsis)),
        ],
       ),
       TweenAnimationBuilder<double>(
        key:ValueKey('$title-$value'),
        tween:Tween<double>(begin:.5,end:position.fraction),
        duration:MediaQuery.disableAnimationsOf(context)?Duration.zero:const Duration(milliseconds:600),
        builder:(context,marker,_)=>SizedBox(
         width:126,
         height:64,
         child:CustomPaint(painter:_GaugePainter(position,marker,color)),
        ),
       ),
       Text(display,style:TextStyle(fontWeight:FontWeight.w700,color:color)),
       Text(position.state,style:TextStyle(fontSize:12,color:color)),
       Text('Target ${lo.toStringAsFixed(0)}–${hi.toStringAsFixed(0)} $unit',style:const TextStyle(fontSize:11,color:muted)),
      ],
     ),
    ),
   ),
  );
 }
}
class _GaugePainter extends CustomPainter{final GaugePosition position;final double marker;final Color color;_GaugePainter(this.position,this.marker,this.color);@override void paint(Canvas canvas,Size size){final rect=Rect.fromLTWH(10,4,size.width-20,size.height*1.7),start=pi,sweep=pi;final track=Paint()..color=line..style=PaintingStyle.stroke..strokeWidth=8..strokeCap=StrokeCap.round;final target=Paint()..color=const Color(0xff1f7a52)..style=PaintingStyle.stroke..strokeWidth=8..strokeCap=StrokeCap.round;canvas.drawArc(rect,start,sweep,false,track);canvas.drawArc(rect,start+sweep*position.bandStart,sweep*(position.bandEnd-position.bandStart),false,target);final center=Offset(rect.center.dx+rect.width/2*cos(start+sweep*marker),rect.center.dy+rect.height/2*sin(start+sweep*marker));canvas.drawCircle(center,6,Paint()..color=color);canvas.drawCircle(center,2,Paint()..color=Colors.white);}@override bool shouldRepaint(covariant _GaugePainter old)=>old.marker!=marker||old.position.fraction!=position.fraction||old.color!=color;}

class _TrendChart extends StatelessWidget {
 final String title,unit,field,range;
 final List<dynamic> points;
 final List<num> band;
 final Color color;
 final int count;
 final Map<String,dynamic>? summary;
 const _TrendChart({required this.title,required this.unit,required this.range,required this.count,required this.summary,required this.points,required this.field,required this.band,required this.color});
 List<double> get values=>points.map((point)=>(point[field] as num?)?.toDouble()).whereType<double>().where((value)=>value.isFinite).toList();
 @override Widget build(BuildContext context){
  final readings=values;
  final low=(summary?['low'] as num?)?.toDouble()??(readings.isEmpty?null:readings.reduce((a,b)=>a<b?a:b));
  final high=(summary?['high'] as num?)?.toDouble()??(readings.isEmpty?null:readings.reduce((a,b)=>a>b?a:b));
  return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('$title ($unit)',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),
   Text('$range · Target band ${band[0]}–${band[1]} $unit · Axis values in $unit',style:const TextStyle(color:muted,fontSize:12)),
   const SizedBox(height:8),
   if(readings.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:28),child:Text('No readings for this time range.',style:TextStyle(color:muted)))
   else Semantics(container:true,label:'$title trend for $range, $count readings, target band ${band[0]} to ${band[1]} $unit. Low ${low!.toStringAsFixed(1)} $unit. High ${high!.toStringAsFixed(1)} $unit.',child:ExcludeSemantics(child:SizedBox(height:205,width:double.infinity,child:CustomPaint(painter:_TrendPainter(points,field,band.map((value)=>value.toDouble()).toList(),color,range))))),
   if(low!=null&&high!=null)Padding(padding:const EdgeInsets.only(top:6),child:Text('$title · $range: Low ${unit=='%'?formatHumidity(low):formatTemperature(low)}, High ${unit=='%'?formatHumidity(high):formatTemperature(high)}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:darkGreen)))
  ])));
 }
}
class _TrendPainter extends CustomPainter {
 final List<dynamic> points;
 final String field,range;
 final List<double> band;
 final Color color;
 _TrendPainter(this.points,this.field,this.band,this.color,this.range);
 String _timeLabel(dynamic value){final date=DateTime.tryParse(value?.toString()??'')?.toLocal();if(date==null)return '';if(range=='24 hours')return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';const months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];return '${months[date.month-1]} ${date.day}';}
 void _drawLabel(Canvas canvas,String text,Offset position,{TextAlign align=TextAlign.left}){final painter=TextPainter(text:TextSpan(text:text,style:const TextStyle(fontSize:9,color:muted)),textDirection:TextDirection.ltr,textAlign:align)..layout();painter.paint(canvas,Offset(align==TextAlign.right?position.dx-painter.width:position.dx,position.dy));}
 @override void paint(Canvas canvas,Size size){
  const left=54.0,right=8.0,top=10.0,bottom=32.0;
  final rect=Rect.fromLTRB(left,top,size.width-right,size.height-bottom);
  if(rect.width<=0||rect.height<=0)return;
  final readings=points.whereType<Map>().where((point)=>(point[field] as num?)?.toDouble().isFinite??false).toList();
  final values=readings.map((point)=>(point[field] as num).toDouble()).toList();
  if(values.isEmpty)return;
  final rawLow=[band[0]-2,...values].reduce((a,b)=>a<b?a:b),rawHigh=[band[1]+2,...values].reduce((a,b)=>a>b?a:b),ticks=niceTicks(rawLow,rawHigh);
  if(ticks.length<2)return;
  final low=ticks.first,high=ticks.last;
  double yy(double value)=>rect.bottom-(value-low)/(high-low)*rect.height;
  double xx(int index)=>rect.left+index*rect.width/(values.length>1?values.length-1:1);
  final grid=Paint()..color=line..strokeWidth=1;
  for(final value in ticks){final y=yy(value);canvas.drawLine(Offset(rect.left,y),Offset(rect.right,y),grid);final digits=(value%1).abs()<.000001?0:1;_drawLabel(canvas,value.toStringAsFixed(digits),Offset(rect.left-8,y-6),align:TextAlign.right);}
  final bandPaint=Paint()..color=color.withOpacity(.12);
  canvas.drawRect(Rect.fromLTRB(rect.left,yy(band[1].clamp(low,high).toDouble()),rect.right,yy(band[0].clamp(low,high).toDouble())),bandPaint);
  if(values.length>1){final path=Path();for(var index=0;index<values.length;index++){final point=Offset(xx(index),yy(values[index]));if(index==0)path.moveTo(point.dx,point.dy);else path.lineTo(point.dx,point.dy);}canvas.drawPath(path,Paint()..color=color..strokeWidth=2.5..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);}else{canvas.drawCircle(Offset(rect.left,yy(values.first)),3,Paint()..color=color);}
  final labelIndexes=<int>{0,(values.length-1)~/2,values.length-1};
  for(final index in labelIndexes){final label=_timeLabel(readings[index]['created_at']);if(label.isEmpty)continue;final alignment=index==0?TextAlign.left:index==values.length-1?TextAlign.right:TextAlign.center;final painter=TextPainter(text:TextSpan(text:label,style:const TextStyle(fontSize:9,color:muted)),textDirection:TextDirection.ltr,textAlign:alignment)..layout();final x=index==0?rect.left:index==values.length-1?rect.right-painter.width:rect.left+rect.width/2-painter.width/2;painter.paint(canvas,Offset(x,rect.bottom+8));}
 }
 @override bool shouldRepaint(covariant _TrendPainter old)=>old.points!=points||old.field!=field||old.band!=band||old.range!=range||old.color!=color;
}
