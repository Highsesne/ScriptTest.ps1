#requires -Version 5.1
# SCRIPT X 5.37 - GRAPHITE DEPTH / SMOKED BORDERLESS FROSTED GLASS
# Background: static black and subtle graphite gradients; no background animation.
# The dashboard's FPS and hardware animations are retained.
# Segoe UI for general text; On Top Regular embedded for the Dashboard heading; retain MDL2 icons.
# Distribution build: reads machine info from the PC running this script.
# No user, GPU, game, installation folder or account name is hard-coded.
# Genuine FPS requires a measured Present() stream. Auto-provisions PresentMon on first launch; RTSS is optional fallback.
# Continuous meters and vector icons; one shared blurred backdrop snapshot for glass surfaces.
[CmdletBinding()]
param(
    [switch]$FpsProbe,
    [switch]$FpsDiagnostics,
    [ValidateRange(0,2147483647)][int]$FpsTargetPid = 0,
    [ValidateRange(1,3600)][int]$FpsProbeSeconds = 120
)

if ($env:OS -ne 'Windows_NT') {
    throw 'SCRIPT X requires Windows 10/11.'
}

# Bootstrap repair for Windows PowerShell 5.1.
# 4.21 launched a NEW elevated PowerShell session without carrying the
# temporary script execution policy. Unsigned .ps1 files could stop before UI.
# Do not modify any machine/user execution policy or UAC setting.
$script:IsElevated = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $script:IsElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch {
    Write-Error ('Could not check Administrator permissions: ' + $_.Exception.Message)
    return
}

$script:StartupLog = Join-Path $env:LOCALAPPDATA 'ScriptX\startup-diagnostics.log'
function Write-HsStartupLog([string]$Message) {
    try {
        $folder = [IO.Path]::GetDirectoryName($script:StartupLog)
        [void][IO.Directory]::CreateDirectory($folder)
        [IO.File]::AppendAllText($script:StartupLog,
            ('[{0}] {1}{2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message, [Environment]::NewLine))
    } catch {}
}

$script:PowerShellExe = Join-Path $PSHOME 'powershell.exe'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $nativeShell = Join-Path $env:WINDIR 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $nativeShell -PathType Leaf) {
        $script:PowerShellExe = $nativeShell
    }
}

# Request UAC only when needed, and pass -STA at the SAME relaunch.
# An encoded one-line launcher preserves Unicode, spaces and quotes in file paths.
$needsAdmin = (-not $script:IsElevated) -and (-not $FpsProbe)
$needsSta = ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') -and (-not $FpsProbe)
if ($needsAdmin -or $needsSta) {
    $scriptFile = [string]$PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptFile = [string]$MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($scriptFile) -or -not (Test-Path -LiteralPath $scriptFile -PathType Leaf)) {
        Write-HsStartupLog 'BOOT_ERROR: Could not identify this .ps1 file for relaunch.'
        Write-Error 'Run HIGHSENSE SHOP from its saved .ps1 file, not by pasting its contents into the terminal.'
        return
    }

    # All substitutions are single-quoted PowerShell string literals.
    $quotedScript = "'" + $scriptFile.Replace("'", "''") + "'"
    $quotedLog = "'" + $script:StartupLog.Replace("'", "''") + "'"
    $bootstrap = @'
try {
    & __PS_SCRIPT__
}
catch {
    $problem = ($_ | Out-String)
    $trace = [string]$_.ScriptStackTrace
    $report = ('[{0}] ADMIN_CHILD_ERROR: {1}{2}{3}{2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $problem, [Environment]::NewLine, $trace)
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName(__LOG_FILE__))
        [IO.File]::AppendAllText(__LOG_FILE__, $report)
    } catch {}
    # The regular launcher is intentionally console-free. Surface startup
    # failures as a dialog rather than waiting forever for hidden Read-Host.
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [void][System.Windows.Forms.MessageBox]::Show(
            'HIGHSENSE SHOP could not start. See: ' + __LOG_FILE__,
            'HIGHSENSE SHOP - Startup error', 'OK', 'Error')
    } catch {}
}
'@
    $forwardFps = ' -FpsTargetPid ' + $FpsTargetPid + ' -FpsProbeSeconds ' + $FpsProbeSeconds
    if ($FpsDiagnostics) { $forwardFps += ' -FpsDiagnostics' }
    $bootstrap = $bootstrap.Replace('__PS_SCRIPT__', ($quotedScript + $forwardFps)).Replace('__LOG_FILE__', $quotedLog)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
    $launchArgs = '-NoLogo -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand ' + $encoded
    # Process-scoped Bypass is necessary only for the relaunched PowerShell;
    # it does not persist or edit the user's execution-policy settings.
    try {
        Write-HsStartupLog ('BOOT_RELAUNCH: AdminRequired={0}, StaRequired={1}' -f $needsAdmin, $needsSta)
        $startArgs = @{
            FilePath = $script:PowerShellExe
            ArgumentList = $launchArgs
            WorkingDirectory = $PSScriptRoot
            ErrorAction = 'Stop'
        }
        if ($needsAdmin) { $startArgs.Verb = 'RunAs' }
        Start-Process @startArgs | Out-Null
    }
    catch {
        Write-HsStartupLog ('BOOT_RELAUNCH_FAILED: ' + ($_ | Out-String))
        Write-Warning ('HIGHSENSE SHOP launch failed or UAC was cancelled: ' + $_.Exception.Message)
        Write-Warning ('Details: ' + $script:StartupLog)
    }
    return
}
Write-HsStartupLog ('BOOT_CONTINUE: Elevated={0}, STA={1}, 64bit={2}' -f `
    $script:IsElevated, ([Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'), [Environment]::Is64BitProcess)

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase



# Broad game capture on Windows via PresentMon (DX/OpenGL/Vulkan); no
# FPS collector can guarantee every engine/anti-cheat/background configuration.
# Independent, no-RTSS capture backend. PresentMon is provisioned automatically to
# the per-user application data folder on first start if an engine is not already available.
# Official upstream: https://github.com/GameTechDev/PresentMon (MIT license)
# MIT NOTICE: Copyright (C) 2017-2024 Intel Corporation.
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to
# do so, subject to the following conditions: The above copyright notice and this
# permission notice shall be included in all copies or substantial portions of
# the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
$script:Fps433Ready = $false
try {
    if (-not ('ScriptXFps472.Engine' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Net;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace ScriptXFps472 {
    public sealed class Snapshot {
        public string State="STARTING", Detail="", Game="", Source="", Identity="", Chain="", ExitedIdentity="";
        public string CaptureStatus="STARTING", RtssStatus="STARTING", Session="", Evidence="UNKNOWN";
        public int Pid;
        public bool Foreground, TargetAlive;
        public double Fps, RawFps, Avg, Peak, Low, FrameMs, FrameAgeMs, ReceiveAgeMs;
        public long Sequence, Frames, PresentCount, LastPresentQpc, ReceivedQpc, SampleQpc, FreshUntilQpc;
        public long StdoutRows, ParsedRows, RejectedRows, ExcludedRows;
        public DateTime SampleUtc;
        public Snapshot Copy() { return (Snapshot)MemberwiseClone(); }
    }
    internal sealed class Frame {
        internal long Qpc;
        internal double Ms;
        internal Frame(long qpc, double ms) { Qpc=qpc; Ms=ms; }
    }
    internal sealed class Stream {
        internal string Key;
        internal readonly LinkedList<Frame> Frames=new LinkedList<Frame>();
        internal long Last, Received, Count, Version;
        internal double LastMs, Peak;
        internal Snapshot Stats;
        internal long StatsVersion=-1;
        internal Stream(string key) { Key=key; }
    }
    internal sealed class RtssProgress {
        internal bool Seen, Advanced;
        internal uint T0, T1, Count;
        internal long Changed, Version;
        internal double Fps, Ms, Elapsed;
        internal readonly Queue<Frame> Windows=new Queue<Frame>();
        internal readonly Queue<uint> Counts=new Queue<uint>();
        internal double Peak;
    }
    internal sealed class App {
        internal int Pid;
        internal string Name;
        internal long StartTicks, Seen, IdentityChecked;
        internal bool Alive, Verified, Visible;
        internal SafeWaitHandle Lifetime;
        internal string IdentityStatus="PENDING";
        internal int[] Ancestors=new int[0];
        internal readonly Dictionary<string,Stream> Streams=new Dictionary<string,Stream>();
        internal readonly RtssProgress Rtss=new RtssProgress();
        internal string Chain="";
        internal App(int pid,string name,long now) { Pid=pid;Name=name;Seen=now; }
        internal string Identity { get { return Pid.ToString(CultureInfo.InvariantCulture)+":"+StartTicks.ToString(CultureInfo.InvariantCulture); } }
    }
    // All mutation runs under Engine.DataGate. Build is independent of window focus/lifecycle.
    internal sealed class MonitorCore {
        internal readonly Dictionary<int,App> Apps=new Dictionary<int,App>();
        internal int TargetPid, RequestedPid;
        internal string TargetIdentity="", ConfirmedExitedIdentity="";
        internal long Version;
        internal static double Age(long now,long then) { return (now-then)*1000.0/Stopwatch.Frequency; }
        internal static long Ticks(double ms) { return (long)(ms*Stopwatch.Frequency/1000.0); }
        internal static double FreshMs(double interval) { return Math.Min(15000,Math.Max(2000,interval*2.5+500)); }
        internal App Get(int pid,string name,long now) {
            App a;
            if(!Apps.TryGetValue(pid,out a)) {
                if(Apps.Count>=64) return null;
                a=new App(pid,name,now); Apps.Add(pid,a);
            }
            a.Name=name; a.Seen=now; return a;
        }
        internal void Present(int pid,string name,string chain,long qpc,double ms,long received) {
            App a=Get(pid,name,received); if(a==null) return;
            Stream c;
            if(!a.Streams.TryGetValue(chain,out c)) {
                if(a.Streams.Count>=8) return;
                c=new Stream(chain);a.Streams.Add(chain,c);
            }
            // Duplicate or delayed/out-of-order rows cannot become fresh evidence.
            if(qpc<=c.Last) return;
            c.Last=qpc;c.Received=received;c.Count++;
            // A zero-interval row is a first-present/discontinuity marker, NOT
            // evidence that all previously measured frames have disappeared.
            // In particular, alt-tab may restart a swap-chain with a zero row.
            // Do not invalidate stats or publish a new FPS sample on that row.
            if(ms>0 && !Double.IsNaN(ms) && !Double.IsInfinity(ms)) {
                c.LastMs=ms;c.Version=++Version;
                c.Frames.AddLast(new Frame(qpc,ms));
            }
            Trim(c,received,TargetPid==pid && a.Chain==chain);
        }
        private static void Trim(Stream c,long now,bool primary) {
            int limit=primary?20000:2048;double horizon=primary?30000:3000;
            while(c.Frames.First!=null && (c.Frames.Count>limit || Age(now,c.Frames.First.Value.Qpc)>horizon))
                c.Frames.RemoveFirst();
        }
        internal void RtssWindow(int pid,string name,uint t0,uint t1,uint count,uint us,long now) {
            App a=Get(pid,name,now);if(a==null) return;
            RtssProgress r=a.Rtss;
            if(!r.Seen) { r.Seen=true;r.T0=t0;r.T1=t1;r.Count=count;return; }
            if(t1==r.T1) return; // First read of an existing mapping is not proof of progress.
            uint advance=unchecked(t1-r.T1);
            r.T0=t0;r.T1=t1;r.Count=count;
            if(advance>0x7fffffff) { r.Advanced=false;r.Windows.Clear();r.Counts.Clear();return; }
            uint elapsed=unchecked(t1-t0);
            if(count==0 || elapsed==0 || elapsed>60000) return;
            r.Advanced=true;r.Changed=now;r.Elapsed=elapsed;r.Fps=1000.0*count/elapsed;
            r.Ms=us>0?us/1000.0:elapsed/(double)count;r.Version=++Version;
            r.Windows.Enqueue(new Frame(now,elapsed));r.Counts.Enqueue(count);
            while(r.Windows.Count>120 || (r.Windows.Count>0 && Age(now,r.Windows.Peek().Qpc)>30000)) {
                r.Windows.Dequeue();r.Counts.Dequeue();
            }
            if(r.Fps>r.Peak) r.Peak=r.Fps;
        }
        internal static bool Fresh(Stream c,long now) {
            // Freshness must depend on the last VALID measured interval,
            // never a zero-ms marker that has no rate measurement.
            return c!=null && c.Frames.Last!=null &&
                Age(now,c.Frames.Last.Value.Qpc)>=-100 &&
                Age(now,c.Frames.Last.Value.Qpc)<=FreshMs(c.LastMs);
        }
        internal static bool Fresh(RtssProgress r,long now) {
            return r.Advanced && Age(now,r.Changed)<=Math.Min(15000,Math.Max(2500,r.Elapsed*2.5+500));
        }
        private static int RecentCount(Stream c,long now) {
            int count=0;
            for(LinkedListNode<Frame> f=c.Frames.Last;f!=null && Age(now,f.Value.Qpc)<=2000;f=f.Previous) count++;
            return count;
        }
        private static Stream PickStream(App a,long now) {
            Stream pinned; a.Streams.TryGetValue(a.Chain,out pinned);
            if(!Fresh(pinned,now)) pinned=null;
            Stream best=pinned;int score=best==null?0:RecentCount(best,now);
            foreach(Stream c in a.Streams.Values) {
                if(!Fresh(c,now)) continue;
                int current=RecentCount(c,now);
                // Keep one primary swap chain, with hysteresis when a sustained busier game chain appears.
                if(best==null || (current>Math.Max(2,score*1.5) && c.Frames.First!=null &&
                    Age(c.Last,c.Frames.First.Value.Qpc)>=1000)) { best=c;score=current; }
            }
            if(best!=null) a.Chain=best.Key;
            return best;
        }
        private static bool HasFrames(App a,long now) {
            if(!a.Alive || !a.Verified) return false;
            if(Fresh(a.Rtss,now)) return true;
            foreach(Stream c in a.Streams.Values) if(Fresh(c,now)) return true;
            return false;
        }
        private static bool BelongsToFocus(App a,int foreground) {
            if(foreground<=0) return false;
            foreach(int ancestor in a.Ancestors) if(ancestor==foreground) return true;
            return false;
        }
        internal Snapshot Build(long now,int foreground) {
            App selected=null,pinned=null;
            Apps.TryGetValue(TargetPid,out pinned);
            if(pinned!=null && (!pinned.Alive || !pinned.Verified || pinned.Identity!=TargetIdentity)) pinned=null;
            if(RequestedPid>0) {
                App requested;
                if(Apps.TryGetValue(RequestedPid,out requested) && requested.Alive && requested.Verified) selected=requested;
            } else {
                App focused;
                if(Apps.TryGetValue(foreground,out focused) && HasFrames(focused,now)) selected=focused;
                // A launcher/window process can own the foreground while a child presents.
                if(selected==null) {
                    App child=null;int matches=0;
                    foreach(App a in Apps.Values) if(HasFrames(a,now) && BelongsToFocus(a,foreground)) { child=a;matches++; }
                    if(matches==1) selected=child;
                }
                if(selected==null) selected=pinned; // Retain identity even if both sources go silent.
                if(selected==null) {
                    App only=null;int matches=0;
                    foreach(App a in Apps.Values) if(a.Visible && HasFrames(a,now)) { only=a;matches++; }
                    if(matches==1) selected=only;
                    else if(matches>1) return new Snapshot {State="MULTIPLE_RENDERERS",Detail="Focus a renderer or use -FpsTargetPid."};
                }
            }
            if(selected==null) {
                TargetPid=0;TargetIdentity="";
                return new Snapshot {State=RequestedPid>0?"TARGET_NOT_OBSERVED":"WAITING_FOR_GAME",
                    ExitedIdentity=ConfirmedExitedIdentity};
            }
            TargetPid=selected.Pid;TargetIdentity=selected.Identity;ConfirmedExitedIdentity="";
            Snapshot s=new Snapshot {Pid=selected.Pid,Game=selected.Name,Identity=selected.Identity,TargetAlive=selected.Alive,
                Foreground=selected.Pid==foreground || BelongsToFocus(selected,foreground),Detail="identity="+selected.IdentityStatus};
            Stream stream=PickStream(selected,now);
            if(stream!=null) {
                // Stats and FPS change only when a real new present is observed.
                if(stream.Stats==null || stream.StatsVersion!=stream.Version) {
                    Trim(stream,now,true);
                    List<double> all=new List<double>();double sum=0,recentSum=0;int recentCount=0;
                    double horizon=Math.Max(1000,Math.Min(15000,stream.LastMs*2.0));
                    foreach(Frame f in stream.Frames) {
                        all.Add(f.Ms);sum+=f.Ms;
                        if(Age(stream.Last,f.Qpc)<=horizon) { recentCount++;recentSum+=f.Ms; }
                    }
                    Snapshot stats=new Snapshot();
                    if(recentCount>0 && recentSum>0) stats.Fps=1000.0*recentCount/recentSum;
                    if(sum>0) stats.Avg=1000.0*all.Count/sum;
                    all.Sort();int worst=(int)Math.Ceiling(all.Count*0.01);double slow=0;
                    for(int i=all.Count-worst;i<all.Count;i++) slow+=all[i];
                    stats.Low=slow>0?1000.0*worst/slow:0;
                    stream.Peak=Math.Max(stream.Peak,stats.Fps);stats.Peak=stream.Peak;
                    stats.Frames=all.Count;stream.Stats=stats;stream.StatsVersion=stream.Version;
                }
                s.State="LIVE";s.Source="PresentMon";s.Chain=stream.Key;s.Sequence=stream.Version;
                s.Fps=stream.Stats.Fps;s.Avg=stream.Stats.Avg;s.Low=stream.Stats.Low;s.Peak=stream.Stats.Peak;
                s.Frames=stream.Stats.Frames;s.FrameMs=stream.LastMs;s.RawFps=stream.LastMs>0?1000.0/stream.LastMs:0;
                s.LastPresentQpc=stream.Last;s.ReceivedQpc=stream.Received;s.PresentCount=stream.Count;
                s.FreshUntilQpc=stream.Frames.Last.Value.Qpc+Ticks(FreshMs(stream.LastMs));
                s.Evidence="PRESENTS_OBSERVED";
            } else if(Fresh(selected.Rtss,now)) {
                RtssProgress r=selected.Rtss;
                s.State="LIVE";s.Source="RTSS";s.Sequence=r.Version;s.Fps=r.Fps;s.RawFps=r.Fps;
                double elapsed=0;ulong count=0;
                foreach(Frame w in r.Windows) elapsed+=w.Ms;
                foreach(uint n in r.Counts) count+=n;
                s.Avg=elapsed>0?1000.0*count/elapsed:0;s.Peak=r.Peak;s.FrameMs=r.Ms;
                s.Frames=(long)count;s.ReceivedQpc=r.Changed;
                // RTSS has no per-present QPC timestamp or per-frame distribution.
                s.FreshUntilQpc=r.Changed+Ticks(Math.Min(15000,Math.Max(2500,r.Elapsed*2.5+500)));
                s.Evidence="RTSS_PROGRESS_PRESENTMON_GAP";
            } else {
                s.State="NO_NEW_PRESENTS";s.Evidence="NO_PROGRESS_CAUSE_UNCONFIRMED";
                Stream previous;
                if(selected.Streams.TryGetValue(selected.Chain,out previous)) {
                    s.LastPresentQpc=previous.Last;s.ReceivedQpc=previous.Received;s.PresentCount=previous.Count;
                }
            }
            s.FrameAgeMs=s.LastPresentQpc>0?Age(now,s.LastPresentQpc):-1;
            s.ReceiveAgeMs=s.ReceivedQpc>0?Age(now,s.ReceivedQpc):-1;
            return s;
        }
    }
    public static class Engine {
        private const string Url="https://github.com/GameTechDev/PresentMon/releases/download/v2.3.1/PresentMon-2.3.1-x64.exe";
        private const string FileName="PresentMon-2.3.1-x64.exe";
        private const string ExpectedSha256="364E5D98D4D134BD54DD25C22ED2CA2F4883F8BC3ED6502BEE0C151E3436D30C";
        private static readonly object Gate=new object(), DataGate=new object(), SnapshotGate=new object(), LogGate=new object();
        private static readonly object TraceStopGate=new object();
        private static readonly HashSet<string> TraceStopped=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private static readonly Queue<string> LogQueue=new Queue<string>();
        private static readonly ManualResetEvent StopSignal=new ManualResetEvent(false);
        private static readonly int OwnPid=Process.GetCurrentProcess().Id;
        private static readonly string[] Exclusions={"dwm.exe","explorer.exe","powershell.exe","pwsh.exe","code.exe",
            "rtss.exe","chrome.exe","msedge.exe","firefox.exe","steamwebhelper.exe","discord.exe","taskmgr.exe",
            "windowsterminal.exe","searchhost.exe","gamebar.exe","presentmon.exe",FileName,"PresentMonConsole.exe"};
        private static MonitorCore core=new MonitorCore();
        private static Snapshot latest=new Snapshot();
        private static string engineRoot,scriptRoot,logPath,activeSession="",captureStatus="STOPPED",rtssStatus="STARTING";
        private static string errorTail="",readerStatus="",schemaStatus="WAITING",lossEvidence="NONE_REPORTED";
        private static Thread runner,sampler;
        private static Process proc;
        private static volatile bool stopped=true,diagnostics;
        private static long lines,usable,rejected,excluded,lastRow,lastSampleLog,lastUiLog;
        private static int appColumn=-1,pidColumn=-1,msColumn=-1,chainColumn=-1,qpcColumn=-1;
        private static bool schemaReady;
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
        [StructLayout(LayoutKind.Sequential)] private struct ProcessBasicInformation {
            public IntPtr Reserved1,Peb,Reserved2,Reserved3,UniquePid,ParentPid;
        }
        [DllImport("ntdll.dll")] private static extern int NtQueryInformationProcess(SafeWaitHandle handle,int kind,
            ref ProcessBasicInformation info,int length,out int returned);
        [DllImport("kernel32.dll",SetLastError=true)] private static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
        [DllImport("kernel32.dll",SetLastError=true)] private static extern uint WaitForSingleObject(SafeWaitHandle handle,uint milliseconds);
        [DllImport("kernel32.dll",SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessTimes(SafeWaitHandle handle,out long created,out long exited,out long kernel,out long user);
        private sealed class BoundedWebClient : WebClient {
            protected override WebRequest GetWebRequest(Uri address) {
                WebRequest r=base.GetWebRequest(address);r.Timeout=15000;
                HttpWebRequest h=r as HttpWebRequest;if(h!=null) h.ReadWriteTimeout=15000;
                return r;
            }
        }
        public static void Start(string root,string scriptFolder,string diagnosticLog,bool enableDiagnostics,int requestedPid) {
            lock(Gate) {
                if((runner!=null && runner.IsAlive) || (sampler!=null && sampler.IsAlive)) return;
                engineRoot=root;scriptRoot=scriptFolder;logPath=diagnosticLog;diagnostics=enableDiagnostics;
                lock(DataGate) { DisposeIdentities();core=new MonitorCore();core.RequestedPid=requestedPid;ResetCapture(); }
                lock(SnapshotGate) latest=new Snapshot();
                stopped=false;StopSignal.Reset();
                sampler=new Thread(SampleLoop);sampler.IsBackground=true;sampler.Name="ScriptX-FPS-Sampling";
                runner=new Thread(Run);runner.IsBackground=true;runner.Name="ScriptX-PresentMon-Capture";
                sampler.Start();runner.Start();
            }
        }
        public static void Stop() {
            Thread capture,worker;Process old;string session;
            lock(Gate) {
                stopped=true;StopSignal.Set();old=proc;session=activeSession;capture=runner;worker=sampler;
            }
            if(old!=null) { try { if(!old.HasExited) old.Kill(); } catch {} }
            StopOwnedTrace(session);
            if(capture!=null && capture!=Thread.CurrentThread) capture.Join(2000);
            if(worker!=null && worker!=Thread.CurrentThread) worker.Join(1500);
            lock(DataGate) DisposeIdentities();
            lock(SnapshotGate) latest=new Snapshot {State="STOPPED",CaptureStatus="STOPPED"};
            FlushLog();
        }
        public static Snapshot GetLatest() {
            Snapshot s;lock(SnapshotGate) s=latest.Copy();
            long now=Stopwatch.GetTimestamp();
            s.FrameAgeMs=s.LastPresentQpc>0?MonitorCore.Age(now,s.LastPresentQpc):-1;
            s.ReceiveAgeMs=s.ReceivedQpc>0?MonitorCore.Age(now,s.ReceivedQpc):-1;
            if(s.State=="LIVE" && (now>s.FreshUntilQpc || MonitorCore.Age(now,s.SampleQpc)>2000)) {
                s.State="STALE_SNAPSHOT";s.Fps=0;s.Evidence="PRODUCER_OR_SOURCE_STALE";
            }
            return s;
        }
        private static void Status(string state,string detail) {
            lock(DataGate) captureStatus=state;
            // Details stay internal; disk logs contain no local paths or raw process arguments.
            Log("CAPTURE state="+state);
        }
        public static string Diagnostic() {
            Snapshot s=GetLatest();return "capture="+s.CaptureStatus+";rtss="+s.RtssStatus+
                ";rows="+s.StdoutRows+";parsed="+s.ParsedRows+";rejected="+s.RejectedRows+";"+s.Detail;
        }
        private static string Safe(string s) {
            if(s==null) return "";
            return s.Replace("\r"," ").Replace("\n"," ").Replace("\t"," ");
        }
        private static string N(double n) { return n.ToString("0.###",CultureInfo.InvariantCulture); }
        private static void Log(string message) {
            if(!diagnostics) return;
            lock(LogGate) {
                if(LogQueue.Count>=256) LogQueue.Dequeue();
                LogQueue.Enqueue(DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture)+" "+Safe(message));
            }
        }
        private static void FlushLog() {
            if(!diagnostics || String.IsNullOrEmpty(logPath)) return;
            lock(LogGate) {
                if(LogQueue.Count==0) return;
                try {
                    Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                    if(File.Exists(logPath) && new FileInfo(logPath).Length>4*1024*1024) {
                        string old=logPath+".1";if(File.Exists(old)) File.Delete(old);File.Move(logPath,old);
                    }
                    using(StreamWriter w=new StreamWriter(logPath,true,Encoding.UTF8))
                        while(LogQueue.Count>0) w.WriteLine(LogQueue.Dequeue());
                } catch { LogQueue.Clear(); }
            }
        }
        public static void RecordUi(string identity,string source,long sequence,string state,double sent,string text,
            double arcTarget,double arcActual,double opacity) {
            if(!diagnostics) return;
            long now=Stopwatch.GetTimestamp();
            if(MonitorCore.Age(now,Interlocked.Read(ref lastUiLog))<1000) return;
            Interlocked.Exchange(ref lastUiLog,now);
            Log("UI identity="+identity+" source="+source+" seq="+sequence+" state="+state+
                " sentFps="+N(sent)+" text="+Safe(text)+" arcTarget="+N(arcTarget)+
                " arcActual="+N(arcActual)+" opacity="+N(opacity));
        }
        private static bool IsExcluded(int pid,string name) {
            if(pid<=4 || pid==OwnPid) return true;
            foreach(string n in Exclusions) if(name.Equals(n,StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }
        private static string BaseName(string name) {
            name=(name??"").Replace('/','\\');int slash=name.LastIndexOf('\\');
            return slash>=0?name.Substring(slash+1):name;
        }
        private static void StopOwnedTrace(string session) {
            if (String.IsNullOrEmpty(session) ||
                !System.Text.RegularExpressions.Regex.IsMatch(session, "^HSFps433_[0-9a-fA-F]{12}$")) return;
            lock (TraceStopGate) {
                if (TraceStopped.Contains(session)) return;
                try {
                    using (Process task=new Process()) {
                        task.StartInfo.FileName=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"logman.exe");
                        task.StartInfo.Arguments="stop "+session+" -ets";
                        task.StartInfo.UseShellExecute=false;
                        task.StartInfo.CreateNoWindow=true;
                        task.StartInfo.WindowStyle=ProcessWindowStyle.Hidden;
                        if (!task.Start()) return;
                        if (!task.WaitForExit(2500)) {
                            try { task.Kill(); } catch { }
                            Log("TRACE_STOP_TIMEOUT: "+session);
                            return;
                        }
                        if (task.ExitCode==0) {
                            TraceStopped.Add(session);
                            Log("TRACE_STOPPED: "+session);
                        } else {
                            // A failed stop can also mean StartTrace never
                            // created the session; no unrelated trace is touched.
                            Log("TRACE_STOP_NOT_FOUND_OR_FAILED: "+session+";code="+task.ExitCode);
                        }
                    }
                } catch (Exception ex) {
                    Log("TRACE_STOP_ERROR: "+session+";"+ex.GetType().Name);
                }
            }
        }
        private static bool IsValidBinary(string file) {
            try {
                FileInfo fi=new FileInfo(file);
                if (!fi.Exists || fi.Length < 100000 || fi.Length > 250000000) return false;
                using (FileStream f=fi.OpenRead()) { return f.ReadByte()==0x4d && f.ReadByte()==0x5a; }
            } catch { return false; }
        }
        private static bool HashMatch(string file) {
            if (!IsValidBinary(file)) return false;
            try {
                using (FileStream f=File.OpenRead(file))
                using (System.Security.Cryptography.SHA256 sha=System.Security.Cryptography.SHA256.Create()) {
                    byte[] bytes=sha.ComputeHash(f);
                    StringBuilder h=new StringBuilder();
                    foreach(byte b in bytes) h.Append(b.ToString("X2",CultureInfo.InvariantCulture));
                    return h.ToString().Equals(ExpectedSha256,StringComparison.OrdinalIgnoreCase);
                }
            } catch { return false; }
        }
        private static string FindEngine() {
            List<string> dirs=new List<string>();
            dirs.Add(engineRoot); dirs.Add(scriptRoot);
            string local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            dirs.Add(Path.Combine(local,"ScriptX","Engines"));
            dirs.Add(Path.Combine(local,"ScriptX","Tools"));
            dirs.Add(Path.Combine(local,"PresentMon"));
            string programFiles=Environment.GetEnvironmentVariable("ProgramFiles");
            if (!String.IsNullOrEmpty(programFiles)) dirs.Add(Path.Combine(programFiles,"PresentMon"));
            string[] names={FileName,"PresentMonConsole.exe"};
            foreach (string dir in dirs) {
                if (String.IsNullOrEmpty(dir)) continue;
                foreach (string name in names) {
                    string path=Path.Combine(dir,name);
                    if (HashMatch(path)) return path;
                }
            }
            return null;
        }
        private static string Provision() {
            string existing=FindEngine();
            if (existing!=null) return existing;
            if (!Environment.Is64BitOperatingSystem) {
                Status("ENGINE_UNSUPPORTED","Windows x64 is required for this capture engine");
                return null;
            }
            Status("ENGINE_DOWNLOADING","Fetching official PresentMon v2.3.1 once; first launch needs Internet");
            string dest=Path.Combine(engineRoot,FileName), temp=dest+"."+Guid.NewGuid().ToString("N")+".download";
            try {
                Directory.CreateDirectory(engineRoot);
                ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
                using (WebClient client=new BoundedWebClient()) {
                    client.Headers.Add("User-Agent","HighSenseShop-FPS/4.33");
                    client.DownloadFile(Url,temp);
                }
                if (!HashMatch(temp)) throw new InvalidDataException("PresentMon SHA-256 verification failed; the downloaded executable will not run");
                if (File.Exists(dest) && !HashMatch(dest)) File.Delete(dest);
                if (!File.Exists(dest)) File.Move(temp,dest);
                else { try { File.Delete(temp); } catch {} }
                Log("ENGINE_READY: official binary obtained from "+Url);
                return HashMatch(dest)?dest:null;
            } catch (Exception ex) {
                Status("ENGINE_DOWNLOAD_FAILED",ex.GetType().Name+": "+ex.Message);
                return null;
            } finally { try { if (File.Exists(temp)) File.Delete(temp); } catch {} }
        }
        private static string ClassifyExit(int code, string error) {
            string s=error??"";
            if (s.IndexOf("error code 1450",StringComparison.OrdinalIgnoreCase)>=0 ||
                s.IndexOf("0x000005aa",StringComparison.OrdinalIgnoreCase)>=0 ||
                s.IndexOf("0x5aa",StringComparison.OrdinalIgnoreCase)>=0)
                return "ETW_RESOURCE_LIMIT";
            if (s.IndexOf("failed to start trace session: access denied",StringComparison.OrdinalIgnoreCase)>=0 ||
                s.IndexOf("error code 5.",StringComparison.OrdinalIgnoreCase)>=0)
                return "ETW_ACCESS_DENIED";
            if (s.IndexOf("failed to start trace session",StringComparison.OrdinalIgnoreCase)>=0)
                return "ETW_START_FAILED";
            return "ENGINE_EXIT";
        }
        private static string[] Csv(string line) {
            List<string> fields=new List<string>();
            StringBuilder sb=new StringBuilder(); bool inside=false;
            for(int i=0;i<line.Length;i++) {
                char c=line[i];
                if(c=='"') {
                    if(inside && i+1<line.Length && line[i+1]=='"') { sb.Append('"'); i++; }
                    else inside=!inside;
                } else if(c==',' && !inside) { fields.Add(sb.ToString()); sb.Length=0; }
                else sb.Append(c);
            }
            fields.Add(sb.ToString()); return fields.ToArray();
        }
        private static int Index(string[] v, params string[] names) {
            for(int i=0;i<v.Length;i++) foreach(string n in names)
                if(v[i].Trim().Trim('"').Equals(n,StringComparison.OrdinalIgnoreCase)) return i;
            return -1;
        }
        private static string Short(string s,int max) { return s==null?"":s.Length<=max?s:s.Substring(s.Length-max); }
        private static void ResetCapture() {
            lock(DataGate) {
                appColumn=pidColumn=msColumn=chainColumn=qpcColumn=-1;schemaReady=false;
                schemaStatus="WAITING";readerStatus="STARTING";errorTail="";lossEvidence="NONE_REPORTED";
                lines=usable=rejected=excluded=lastRow=0;
                foreach(App a in core.Apps.Values) { a.Streams.Clear();a.Chain=""; }
            }
        }
        private static void Run() {
            try {
                string path=Provision();if(path==null || stopped) return;
                int attempt=0;
                while(!stopped) {
                    string failure="";ResetCapture();
                    string session="HSFps433_"+Guid.NewGuid().ToString("N").Substring(0,12);
                    Process p=new Process();Thread output=null,errors=null;bool readersFailed=false;
                    p.StartInfo.FileName=path;
                    // Measure app presents, including occluded/background presents; display completion is unnecessary.
                    // v1 + qpc_time has a documented QPCTime/SwapChainAddress/msBetweenPresents schema in 2.3.1.
                    p.StartInfo.Arguments="--session_name "+session+
                        " --output_stdout --v1_metrics --qpc_time --no_track_display --no_track_gpu --no_track_input";
                    p.StartInfo.UseShellExecute=false;p.StartInfo.RedirectStandardOutput=true;
                    p.StartInfo.RedirectStandardError=true;p.StartInfo.CreateNoWindow=true;
                    p.StartInfo.WindowStyle=ProcessWindowStyle.Hidden;
                    try {
                        Status("ENGINE_STARTING","");
                        lock(Gate) {
                            if(stopped) break;
                            if(!p.Start()) throw new InvalidOperationException();
                            proc=p;activeSession=session;
                        }
                        Status("RUNNING","");
                        StreamReader stdout=p.StandardOutput,stderr=p.StandardError;
                        output=new Thread(delegate() { ReadStdout(stdout); });output.IsBackground=true;output.Start();
                        errors=new Thread(delegate() { ReadErrors(stderr); });errors.IsBackground=true;errors.Start();
                        while(!StopSignal.WaitOne(250) && !p.HasExited) { }
                        if(stopped && !p.HasExited) p.Kill();
                        p.WaitForExit(1500);
                        if(errors!=null) errors.Join(1000);
                        lock(DataGate) failure=ClassifyExit(p.ExitCode,errorTail);
                        if(!stopped) Status(failure,"");
                    } catch(Exception ex) {
                        if(!stopped) Status("ENGINE_START_ERROR",ex.GetType().Name);
                    } finally {
                        try { if(!p.HasExited) p.Kill();p.WaitForExit(1000); } catch {}
                        // Drain/join the previous reader before reusing state for another session.
                        if(output!=null && !output.Join(1500)) { try { p.StandardOutput.Close(); } catch {} output.Join(500); }
                        if(errors!=null && !errors.Join(1000)) { try { p.StandardError.Close(); } catch {} errors.Join(500); }
                        StopOwnedTrace(session);
                        lock(Gate) { if(proc==p) proc=null;if(activeSession==session) activeSession=""; }
                        p.Dispose();
                        // Never start a new capture generation while an old reader can mutate it.
                        if((output!=null && output.IsAlive) || (errors!=null && errors.IsAlive)) {
                            Status("READER_STOP_FAILED","");readersFailed=true;
                        }
                    }
                    if(readersFailed) break;
                    attempt++;int seconds=failure=="ETW_RESOURCE_LIMIT"?60:Math.Min(15,3+attempt*2);
                    if(StopSignal.WaitOne(seconds*1000)) break;
                }
            } catch(Exception ex) { Status("CAPTURE_WORKER_ERROR",ex.GetType().Name); }
            finally { if(stopped) Status("STOPPED",""); }
        }
        private static void ReadErrors(StreamReader reader) {
            try {
                string line;
                while(!stopped && (line=reader.ReadLine())!=null) {
                    lock(DataGate) {
                        errorTail=Short(errorTail+" | "+line,2000);
                        if(line.IndexOf("lost",StringComparison.OrdinalIgnoreCase)>=0)
                            lossEvidence="CHECK_PRESENTMON_LOSS_WARNING";
                    }
                }
            } catch { if(!stopped) Log("STDERR_READ_ERROR"); }
        }
        private static void ReadStdout(StreamReader reader) {
            try {
                string line;while(!stopped && (line=reader.ReadLine())!=null) IngestLine(line,Stopwatch.GetTimestamp());
                lock(DataGate) readerStatus=stopped?"STOPPED":"EOF";
            } catch { lock(DataGate) readerStatus=stopped?"STOPPED":"READ_ERROR"; }
        }
        private static void IngestLine(string line,long now) {
            line=line.Replace("\0","").TrimStart('\uFEFF',' ','\t');if(line.Length==0) return;
            string[] f=Csv(line);
            lock(DataGate) {
                lines++;lastRow=now;readerStatus="READING";
                if(Index(f,"Application")>=0 && Index(f,"ProcessID")>=0) {
                    appColumn=Index(f,"Application");pidColumn=Index(f,"ProcessID");msColumn=Index(f,"msBetweenPresents");
                    chainColumn=Index(f,"SwapChainAddress");qpcColumn=Index(f,"QPCTime");
                    schemaReady=appColumn>=0 && pidColumn>=0 && msColumn>=0 && chainColumn>=0 && qpcColumn>=0;
                    schemaStatus=schemaReady?"VALID":"SCHEMA_UNSUPPORTED";Log("CSV schema="+schemaStatus);return;
                }
                if(!schemaReady) { rejected++;return; }
                int max=Math.Max(Math.Max(appColumn,pidColumn),Math.Max(msColumn,Math.Max(chainColumn,qpcColumn)));
                int pid;long qpc;double ms;
                if(f.Length<=max || !Int32.TryParse(f[pidColumn],out pid) ||
                    !Int64.TryParse(f[qpcColumn],NumberStyles.Integer,CultureInfo.InvariantCulture,out qpc) ||
                    !Double.TryParse(f[msColumn],NumberStyles.Float,CultureInfo.InvariantCulture,out ms) ||
                    qpc<=0 || MonitorCore.Age(now,qpc)<-100 || ms<0 || Double.IsNaN(ms) || Double.IsInfinity(ms)) {
                    rejected++;return;
                }
                string name=BaseName(f[appColumn]);
                if(IsExcluded(pid,name)) { excluded++;return; }
                if(String.IsNullOrWhiteSpace(name) || name=="<unknown>") { rejected++;return; }
                usable++;
                core.Present(pid,name,f[chainColumn],qpc,ms,now);
            }
        }
        private static int[] Ancestors(Process p,SafeWaitHandle lifetime) {
            List<int> ids=new List<int>();
            try {
                ProcessBasicInformation info=new ProcessBasicInformation();int size;
                if(NtQueryInformationProcess(lifetime,0,ref info,Marshal.SizeOf(typeof(ProcessBasicInformation)),out size)!=0)
                    return ids.ToArray();
                int parent=info.ParentPid.ToInt32();
                // Direct parent covers common launcher/renderer splits. Only follow a valid creation order.
                if(parent>4 && parent!=p.Id) using(Process pp=Process.GetProcessById(parent))
                    if(pp.StartTime.ToUniversalTime()<=p.StartTime.ToUniversalTime()) ids.Add(parent);
            } catch {}
            return ids.ToArray();
        }
        private static void DisposeIdentities() {
            foreach(App a in core.Apps.Values) {
                if(a.Lifetime!=null) { a.Lifetime.Dispose();a.Lifetime=null; }
                a.Alive=false;a.Verified=false;
            }
        }
        private static bool CurrentApp(App app) {
            App current;return !stopped && core.Apps.TryGetValue(app.Pid,out current) && Object.ReferenceEquals(app,current);
        }
        private static void ForgetApp(App a,string reason) {
            // Caller holds DataGate. No wildcard process operations or unrelated handles.
            if(!CurrentApp(a)) return;
            // Only an OS-confirmed process exit can initiate the zero-return visual.
            // A lost measurement, window focus or capture restart is NOT an exit.
            if((reason=="PROCESS_EXITED" || reason=="PROCESS_NOT_FOUND") &&
                core.TargetPid==a.Pid && core.TargetIdentity==a.Identity)
                core.ConfirmedExitedIdentity=a.Identity;
            a.Alive=false;a.Verified=false;core.Apps.Remove(a.Pid);
            if(a.Lifetime!=null) { a.Lifetime.Dispose();a.Lifetime=null; }
            Log("TARGET_REMOVED pid="+a.Pid+" reason="+reason);
        }
        private static void RefreshIdentities(long now) {
            List<App> due=new List<App>();
            lock(DataGate) {
                foreach(App a in core.Apps.Values) {
                    if(a.IdentityChecked>0 && MonitorCore.Age(now,a.IdentityChecked)<1000) continue;
                    a.IdentityChecked=now;due.Add(a);
                }
            }
            // OS metadata calls never hold the CSV ingestion lock. After initial verification,
            // a read-only lifetime handle checks exit without reopening/querying the process every second.
            foreach(App a in due) {
                if(stopped) return;
                SafeWaitHandle opened=null;
                try {
                    if(a.Lifetime!=null) {
                        uint wait=WaitForSingleObject(a.Lifetime,0);
                        lock(DataGate) {
                            if(!CurrentApp(a)) continue;
                            if(wait==0) { ForgetApp(a,"PROCESS_EXITED");continue; }
                            a.IdentityStatus=wait==258?"VERIFIED_HANDLE":"LIFETIME_CHECK_UNCONFIRMED";
                        }
                        if(wait==258 && !a.Visible) {
                            bool visible;
                            using(Process p=Process.GetProcessById(a.Pid)) visible=p.MainWindowHandle!=IntPtr.Zero;
                            lock(DataGate) if(CurrentApp(a)) a.Visible=visible;
                        }
                    } else {
                        IntPtr raw=OpenProcess(0x00101000,false,a.Pid); // SYNCHRONIZE | QUERY_LIMITED_INFORMATION only
                        if(raw==IntPtr.Zero) {
                            int error=Marshal.GetLastWin32Error();
                            lock(DataGate) {
                                if(CurrentApp(a)) {
                                    if(error==87) ForgetApp(a,"PROCESS_NOT_FOUND");
                                    else a.IdentityStatus="OPEN_DENIED_OR_UNAVAILABLE";
                                }
                            }
                            continue;
                        }
                        opened=new SafeWaitHandle(raw,true);
                        long created,exitTime,kernel,user;
                        if(!GetProcessTimes(opened,out created,out exitTime,out kernel,out user)) continue;
                        long start=DateTime.FromFileTimeUtc(created).Ticks;
                        string actual;bool visible;int[] parents;
                        using(Process p=Process.GetProcessById(a.Pid)) {
                            actual=p.ProcessName+".exe";visible=p.MainWindowHandle!=IntPtr.Zero;parents=Ancestors(p,opened);
                        }
                        if(WaitForSingleObject(opened,0)==0) {
                            lock(DataGate) ForgetApp(a,"PROCESS_EXITED");continue;
                        }
                        lock(DataGate) {
                            if(!CurrentApp(a)) continue;
                            if(IsExcluded(a.Pid,actual) || !actual.Equals(a.Name,StringComparison.OrdinalIgnoreCase) ||
                                (a.StartTicks!=0 && a.StartTicks!=start)) { ForgetApp(a,"IDENTITY_MISMATCH");continue; }
                            long checkedAt=Stopwatch.GetTimestamp();
                            long born=checkedAt-MonitorCore.Ticks((DateTime.UtcNow-new DateTime(start,DateTimeKind.Utc)).TotalMilliseconds);
                            List<string> preBirth=new List<string>();
                            foreach(Stream c in a.Streams.Values) {
                                while(c.Frames.First!=null && c.Frames.First.Value.Qpc<born) c.Frames.RemoveFirst();
                                if(c.Last<born) preBirth.Add(c.Key);
                            }
                            foreach(string key in preBirth) a.Streams.Remove(key);
                            a.StartTicks=start;a.Alive=true;a.Verified=true;a.Visible=visible;a.Ancestors=parents;
                            a.IdentityStatus="VERIFIED_HANDLE";a.Lifetime=opened;opened=null;
                        }
                    }
                } catch(ArgumentException) {
                    lock(DataGate) ForgetApp(a,"PROCESS_NOT_FOUND");
                } catch(Exception ex) {
                    // A transient metadata failure is not an exit event. A verified lifetime
                    // remains pinned; freshness still independently requires actual new frames.
                    lock(DataGate) if(CurrentApp(a)) a.IdentityStatus="CHECK_UNCONFIRMED";
                    Log("IDENTITY_CHECK pid="+a.Pid+" result="+ex.GetType().Name);
                } finally { if(opened!=null) opened.Dispose(); }
                lock(DataGate) {
                    if(!CurrentApp(a)) continue;
                    long checkedAt=Stopwatch.GetTimestamp();
                    if(a.Pid!=core.TargetPid && MonitorCore.Age(checkedAt,a.Seen)>30000) { ForgetApp(a,"INACTIVE_CANDIDATE");continue; }
                    List<string> old=new List<string>();
                    foreach(Stream c in a.Streams.Values) if(c.Key!=a.Chain && MonitorCore.Age(checkedAt,c.Received)>30000) old.Add(c.Key);
                    foreach(string key in old) a.Streams.Remove(key);
                }
            }
        }
        private static Snapshot BuildCurrentSnapshot(int foreground) {
            lock(DataGate) {
                // Take the clock AFTER acquiring the ingestion lock. New CSV frames may have
                // arrived while RTSS/metadata work ran; never judge them against an earlier tick.
                long now=Stopwatch.GetTimestamp();
                Snapshot s=core.Build(now,foreground);
                s.CaptureStatus=captureStatus;s.RtssStatus=rtssStatus;
                s.StdoutRows=lines;s.ParsedRows=usable;s.RejectedRows=rejected;s.ExcludedRows=excluded;
                s.Detail+=";schema="+schemaStatus+";reader="+readerStatus+";loss="+lossEvidence+
                    ";lastRowAgeMs="+(lastRow>0?N(MonitorCore.Age(now,lastRow)):"unknown");
                if(s.State!="LIVE" && (captureStatus!="RUNNING" || readerStatus=="EOF" || readerStatus=="READ_ERROR" || schemaStatus=="SCHEMA_UNSUPPORTED"))
                    s.Evidence="CAPTURE_UNAVAILABLE";
                s.SampleQpc=now;s.SampleUtc=DateTime.UtcNow;return s;
            }
        }
        private static void PublishSamplerFailure() {
            lock(SnapshotGate) {
                Snapshot failure=latest.Copy();failure.State="SAMPLER_ERROR";
                failure.Fps=0;failure.Evidence="PROCESSING_FAILED";latest=failure;
            }
        }
        private static void SampleLoop() {
            long lastRtss=0;
            try {
                while(!stopped) {
                    long now=Stopwatch.GetTimestamp();
                    if(MonitorCore.Age(now,lastRtss)>=500) { ReadRtss(now);lastRtss=now; }
                    uint foreground=0;
                    try { IntPtr hwnd=GetForegroundWindow();if(hwnd!=IntPtr.Zero) GetWindowThreadProcessId(hwnd,out foreground); } catch {}
                    RefreshIdentities(Stopwatch.GetTimestamp());
                    Snapshot s=BuildCurrentSnapshot((int)foreground);
                    now=s.SampleQpc;
                    lock(Gate) s.Session=activeSession;
                    lock(SnapshotGate) latest=s;
                    if(diagnostics && MonitorCore.Age(now,lastSampleLog)>=1000) {
                        lastSampleLog=now;
                        Log("SAMPLE pid="+s.Pid+" name="+s.Game+" identity="+s.Identity+" foreground="+s.Foreground+
                            " source="+s.Source+" state="+s.State+" capture="+s.CaptureStatus+" session="+s.Session+
                            " rtss="+s.RtssStatus+" evidence="+s.Evidence+" chain="+s.Chain+" seq="+s.Sequence+
                            " presentCount="+s.PresentCount+" lastPresentQpc="+s.LastPresentQpc+" frameAgeMs="+N(s.FrameAgeMs)+
                            " receiveAgeMs="+N(s.ReceiveAgeMs)+" rawFps="+N(s.RawFps)+" calculatedFps="+N(s.Fps)+
                            " targetAlive="+s.TargetAlive+" sampleQpc="+s.SampleQpc+" rows="+s.StdoutRows+" parsed="+s.ParsedRows+
                            " rejected="+s.RejectedRows+" excluded="+s.ExcludedRows+" "+s.Detail);
                        FlushLog();
                    }
                    if(StopSignal.WaitOne(250)) break;
                }
            } catch(Exception ex) {
                Log("SAMPLER_ERROR type="+ex.GetType().Name);
                PublishSamplerFailure();
            } finally { FlushLog(); }
        }
        private static void ReadRtss(long now) {
            string status="MAPPING_NOT_FOUND";
            foreach(string name in new string[]{"RTSSSharedMemoryV2",@"Global\RTSSSharedMemoryV2"}) {
                try {
                    using(MemoryMappedFile map=MemoryMappedFile.OpenExisting(name,MemoryMappedFileRights.Read))
                    using(MemoryMappedViewAccessor v=map.CreateViewAccessor(0,0,MemoryMappedFileAccess.Read)) {
                        if(v.Capacity<36 || v.ReadUInt32(0)!=0x52545353) { status="BAD_HEADER";continue; }
                        uint version=v.ReadUInt32(4);
                        long size=v.ReadUInt32(8),offset=v.ReadUInt32(12),count=v.ReadUInt32(16);
                        if((version>>16)!=2 || size<284 || size>1048576 || offset<36 || offset>v.Capacity ||
                            count<1 || count>4096 || count>(v.Capacity-offset)/size) { status="LAYOUT_UNSUPPORTED";continue; }
                        int accepted=0;
                        for(long i=0;i<count;i++) {
                            long pos=offset+i*size;uint id=v.ReadUInt32(pos);if(id<=4 || id>Int32.MaxValue || id==OwnPid) continue;
                            uint t0=v.ReadUInt32(pos+268),t1=v.ReadUInt32(pos+272),frames=v.ReadUInt32(pos+276),us=v.ReadUInt32(pos+280);
                            if(frames==0 || unchecked(t1-t0)==0 || unchecked(t1-t0)>60000) continue;
                            byte[] bytes=new byte[260];v.ReadArray<byte>(pos+4,bytes,0,260);
                            int end=Array.IndexOf<byte>(bytes,0);string app=BaseName(Encoding.Default.GetString(bytes,0,end<0?260:end));
                            if(IsExcluded((int)id,app) || String.IsNullOrWhiteSpace(app)) continue;
                            // Read-only SDK mapping has no reader lock; reject torn window/slot reads.
                            Thread.MemoryBarrier();
                            if(id!=v.ReadUInt32(pos) || t0!=v.ReadUInt32(pos+268) || t1!=v.ReadUInt32(pos+272) ||
                                frames!=v.ReadUInt32(pos+276)) continue;
                            lock(DataGate) core.RtssWindow((int)id,app,t0,t1,frames,us,Stopwatch.GetTimestamp());
                            accepted++;
                        }
                        status=accepted>0?"MAPPING_READ":"NO_MEASURED_WINDOWS";
                        break;
                    }
                } catch(FileNotFoundException) {} catch(UnauthorizedAccessException) { status="ACCESS_DENIED"; }
                catch(System.Security.SecurityException) { status="ACCESS_DENIED"; }
                catch(IOException) { status="MAP_IO_ERROR"; }
                catch { status="READ_ERROR"; }
            }
            lock(DataGate) rtssStatus=status;
        }
    }
}

'@ -IgnoreWarnings -ErrorAction Stop
    }
    $script:Fps433Ready = ('ScriptXFps472.Engine' -as [type]) -ne $null
} catch {
    Write-HsStartupLog ('FPS_COMPILE_FAILED: ' + ($_ | Out-String))
}
$script:Fps433EngineRoot = Join-Path $env:LOCALAPPDATA 'ScriptX\Engines'
$script:Fps433Log = Join-Path $env:LOCALAPPDATA 'ScriptX\fps-diagnostics.log'
function Start-Fps433Engine {
    if ($script:Fps433Ready) {
        [ScriptXFps472.Engine]::Start($script:Fps433EngineRoot, $PSScriptRoot,
            $script:Fps433Log, [bool]($FpsDiagnostics -or $FpsProbe), [int]$FpsTargetPid)
    }
}
function Stop-Fps433Engine {
    if ($script:Fps433Ready) { [ScriptXFps472.Engine]::Stop() }
}

# FPS-only compositor: WPF linear clocks track genuine samples without the
# previous restart/ease-out jolt; number reads the same animated arc position.
# Single active-ring shadow follows the existing WPF animated stroke; no second arc.
# No new timer, extra game sampling, synthetic FPS readings, or endless loop.
$script:FpsNativeGaugeReady = $false
try {
    if (-not ('ScriptXVisual476.FluidFpsGauge' -as [type])) {
        $fpsRendererSource = @'
using System;
using System.Diagnostics;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace ScriptXVisual476 {
    // Genuine FPS samples only; animation is display interpolation, never capture.
    // Retarget the native WPF clocks linearly: no repeated ease-out / stop-go at
    // the ~250 ms sampling boundary. Text reads the same animated arc position.
    public sealed class FluidFpsGauge : IDisposable {
        private const double DashLength = 43.93;
        // Optional halo support remains for compatibility; current XAML uses
        // only the 8px active path with a lightweight glow effect.
        private const double GlowDashRatio = 8.0 / 13.0;
        private const double VisualScale = 360.0;
        private const double MinArc = 0.06;
        private const double ArcEpsilon = 0.004;
        // Each WPF compositor path has its own synchronized native clock.
        // Both use the original 8px gauge geometry; the halo has a wider pen.
        private readonly Path ring;
        private readonly Path glow;
        private readonly TextBlock number;
        private readonly EventHandler renderHandler;
        private bool visible, hooked, hasReading, held, exiting, disposed;
        private double actual, target, renderRate;
        private string drawnLabel;
        private long rateTick;
        private int framesSinceRate;
        // TextBlock.Text invalidates WPF text layout. Do not rebuild it on
        // every frame of the animated path, particularly on layered HWNDs.
        private long lastTextTick;
        private const double TextIntervalMs = 30.0; // ~30 text updates/s at most
        private double worstRenderGapMs;
        private long previousRenderTick;

        public FluidFpsGauge(Path progressRing, Path glowRing, TextBlock fpsNumber) {
            if (progressRing == null || fpsNumber == null)
                throw new ArgumentNullException("FPS controls missing from UI");
            ring = progressRing;
            glow = glowRing;
            number = fpsNumber;
            renderHandler = new EventHandler(OnRendering);
            Reset();
        }

        public double DisplayValue { get { return actual; } }
        public double LatestTarget { get { return target; } }
        // CompositionTarget.Rendering callback frequency, NOT the game's FPS.
        public double RenderHz { get { return renderRate; } }
        // Actual time between WPF Rendering callbacks; useful for FPS diagnostics.
        public double WorstRenderGapMs { get { return worstRenderGapMs; } }
        public bool IsHeld { get { return held; } }

        private static double OffsetFor(double fps) {
            double fraction = fps > 0.0 ? Math.Max(MinArc, Math.Min(1.0, fps / VisualScale)) : 0.0;
            return DashLength * (1.0 - fraction);
        }

        private static double FpsForOffset(double offset) {
            return Math.Max(0.0, Math.Min(VisualScale,
                (1.0 - offset / DashLength) * VisualScale));
        }

        private static void CancelClock(Path path) {
            if (path == null) return;
            double displayed = path.StrokeDashOffset;
            path.BeginAnimation(Shape.StrokeDashOffsetProperty, null);
            path.StrokeDashOffset = displayed;
        }

        private void StopArcClock() {
            CancelClock(ring);
            CancelClock(glow);
        }

        private void SnapArc(double fps) {
            StopArcClock();
            double offset = OffsetFor(fps);
            ring.StrokeDashOffset = offset;
            if (glow != null) glow.StrokeDashOffset = offset * GlowDashRatio;
        }

        private static void StartClock(Path path, double from, double to, double milliseconds,
            EventHandler completed) {
            if (path == null) return;
            // WPF composition owns interpolation; no PowerShell repaint or new timer.
            DoubleAnimation anim = new DoubleAnimation();
            anim.From = from;
            anim.To = to;
            anim.Duration = new Duration(TimeSpan.FromMilliseconds(milliseconds));
            anim.FillBehavior = FillBehavior.HoldEnd;
            // Linear motion prevents resetting the velocity to almost zero
            // with each fresh (typically 250ms) telemetry sample.
            if (completed != null) anim.Completed += completed;
            path.StrokeDashOffset = to;
            path.BeginAnimation(Shape.StrokeDashOffsetProperty, anim,
                HandoffBehavior.SnapshotAndReplace);
        }

        private void AnimateArc(double fps, bool exit) {
            if (!visible) return;
            double from = ring.StrokeDashOffset;
            double to = exit ? DashLength : OffsetFor(fps);
            double glowFrom = glow != null ? glow.StrokeDashOffset : 0.0;
            if (Math.Abs(from - to) < ArcEpsilon && !exit) return;
            // Normal clocks intentionally overlap the measured sample cadence.
            // This avoids an artificial rest every 250ms while preserving
            // immediate reaction when the measured FPS changes direction.
            double durationMs = exit ? 620.0 : 390.0;
            EventHandler finished = null;
            if (exit) finished = (sender, args) => {
                if (!disposed && exiting && target == 0.0) Reset();
            };
            StartClock(ring, from, to, durationMs, finished);
            // Native clocks share the same linear duration; rescale dash units
            // so the broader halo never extends beyond the luminous active arc.
            if (glow != null) StartClock(glow, glowFrom,
                to * GlowDashRatio, durationMs, null);
            // No bitmap blur effect, additional timer or PowerShell repaint.
            HookIfMoving();
        }

        public void SetVisible(bool value) {
            if (disposed || visible == value) return;
            visible = value;
            if (!value) { StopArcClock(); Unhook(); return; }
            if (exiting) { Reset(); return; }
            if (hasReading) {
                // The collector continued off-screen; resume the latest truth.
                actual = target;
                SnapArc(target);
                FadeRing(held ? 0.65 : 1.0);
                number.Opacity = held ? 0.66 : 1.0;
                PaintNumber();
            }
        }

        public void SetSample(double fps) {
            if (disposed || !(fps > 0.0) || Double.IsNaN(fps) || Double.IsInfinity(fps)) return;
            bool first = !hasReading || exiting;
            bool resume = held || exiting;
            if (first) actual = fps;
            target = fps;
            hasReading = true;
            held = false;
            exiting = false;
            if (!visible) return;
            if (first) SnapArc(fps);
            else AnimateArc(fps, false);
            if (first || resume) {
                FadeRing(1.0);
                number.Opacity = 1.0;
            }
            PaintNumber();
        }

        public void Hold() {
            if (disposed || !hasReading || held || exiting) return;
            held = true;
            // Freezing the visual is not pretending to measure a new sample.
            actual = (target < VisualScale * MinArc || target > VisualScale)
                ? target : FpsForOffset(ring.StrokeDashOffset);
            target = actual;
            StopArcClock();
            Unhook();
            if (visible) {
                FadeRing(0.65);
                number.Opacity = 0.66;
                PaintNumber();
            }
        }

        // Only called on confirmed game-process exit; visual 0 is cleared.
        public void ExitToZero() {
            if (disposed || !hasReading || exiting) return;
            exiting = true;
            held = false;
            target = 0.0;
            if (!visible) { Reset(); return; }
            FadeRing(1.0);
            number.Opacity = 1.0;
            AnimateArc(0.0, true);
        }

        public void Reset() {
            if (disposed) return;
            Unhook();
            hasReading = false;
            held = false;
            exiting = false;
            actual = target = 0.0;
            renderRate = 0.0;
            framesSinceRate = 0;
            rateTick = 0;
            drawnLabel = null;
            lastTextTick = previousRenderTick = 0;
            worstRenderGapMs = 0;
            ring.BeginAnimation(UIElement.OpacityProperty, null);
            ring.BeginAnimation(Shape.StrokeDashOffsetProperty, null);
            ring.Opacity = 0.0;
            ring.StrokeDashOffset = DashLength;
            if (glow != null) {
                glow.BeginAnimation(UIElement.OpacityProperty, null);
                glow.BeginAnimation(Shape.StrokeDashOffsetProperty, null);
                glow.StrokeDashOffset = DashLength * GlowDashRatio;
                // Halo dash tracks the active arc; a reset hides both paths.
                glow.Opacity = 0.0;
            }
            number.Text = String.Empty;
            number.Opacity = 1.0;
        }

        private static void FadePath(Path path, double to) {
            if (path == null) return;
            DoubleAnimation fade = new DoubleAnimation();
            fade.From = path.Opacity;
            fade.To = to;
            fade.Duration = new Duration(TimeSpan.FromMilliseconds(170));
            fade.FillBehavior = FillBehavior.HoldEnd;
            path.BeginAnimation(UIElement.OpacityProperty, fade,
                HandoffBehavior.SnapshotAndReplace);
        }

        private void FadeRing(double to) {
            FadePath(ring, to);
            // Keep the surrounding moving halo soft, not a second solid ring.
            FadePath(glow, to * 0.34);
        }

        private void HookIfMoving() {
            if (disposed || !visible || !hasReading || held || hooked) return;
            // Called only for a true retarget / confirmed exit. Do not infer
            // animation completion from a dependency property's base value.
            rateTick = 0;
            framesSinceRate = 0;
            CompositionTarget.Rendering += renderHandler;
            hooked = true;
        }

        private void Unhook() {
            if (!hooked) return;
            CompositionTarget.Rendering -= renderHandler;
            hooked = false;
        }

        private void OnRendering(object sender, EventArgs args) {
            if (!visible || (held && !exiting) || !hasReading || disposed) {
                Unhook(); return;
            }
            // Keep the frequently animated ring under WPF's native clock.
            // Reads only, and amortize expensive TextBlock layout changes.
            long now = Stopwatch.GetTimestamp();
            if (previousRenderTick != 0) {
                double gapMs = (now - previousRenderTick) * 1000.0 / Stopwatch.Frequency;
                if (gapMs > worstRenderGapMs && gapMs < 2000.0) worstRenderGapMs = gapMs;
            }
            previousRenderTick = now;
            double currentOffset = ring.StrokeDashOffset;
            double mapped = FpsForOffset(currentOffset);
            // The ring saturates at 360 FPS and has a 6% visibility floor.
            // Do not clamp the genuine label at either boundary.
            actual = !exiting && (target < VisualScale * MinArc || target > VisualScale)
                ? target : mapped;
            if (lastTextTick == 0 || (now - lastTextTick) * 1000.0 / Stopwatch.Frequency >= TextIntervalMs) {
                lastTextTick = now;
                PaintNumber();
            }

            if (rateTick == 0) rateTick = now;
            framesSinceRate++;
            double elapsed = (double)(now-rateTick) / Stopwatch.Frequency;
            if (elapsed >= 1.0) {
                renderRate = framesSinceRate / elapsed;
                framesSinceRate = 0;
                rateTick = now;
            }
            // Exit's clock Completed callback owns clearing the idle state.
            if (!exiting && Math.Abs(currentOffset - OffsetFor(target)) < ArcEpsilon)
                Unhook();
        }

        private void PaintNumber() {
            if (!visible || !hasReading) return;
            // During game exit never expose fractional near-zero values such
            // as 0.374829. These were the large/flickering digit strings seen
            // just before the previous exit animation cleared the ring.
            // The visual return-to-zero is not a measured FPS sample.
            string text;
            if (exiting) {
                text = actual < 1.0 ? String.Empty :
                    Math.Round(actual, 0, MidpointRounding.AwayFromZero)
                        .ToString("0", CultureInfo.CurrentCulture);
            } else if (actual < 1.0) {
                // Small *genuine* measurements keep modest precision.
                text = actual.ToString("0.0#", CultureInfo.CurrentCulture);
            } else if (actual < 10.0) {
                text = actual.ToString("0.0", CultureInfo.CurrentCulture);
            } else {
                text = Math.Round(actual, 0, MidpointRounding.AwayFromZero)
                    .ToString("0", CultureInfo.CurrentCulture);
            }
            if (!String.Equals(drawnLabel, text, StringComparison.Ordinal)) {
                number.Text = text;
                drawnLabel = text;
            }
        }

        public void Dispose() {
            if (disposed) return;
            Reset();
            disposed = true;
        }
    }
}
'@
        # WPF Path/Shape references IQueryAmbient from System.Xaml on .NET Framework.
        # Without this reference Add-Type falls back to the slower PowerShell gauge.
        Add-Type -AssemblyName System.Xaml -ErrorAction Stop
        $fpsRendererRefs = @(
            [Windows.Media.CompositionTarget].Assembly.Location,
            [Windows.Controls.TextBlock].Assembly.Location,
            [Windows.DependencyObject].Assembly.Location,
            [System.Xaml.XamlReader].Assembly.Location,
            [Diagnostics.Stopwatch].Assembly.Location
        ) | Select-Object -Unique
        Add-Type -TypeDefinition $fpsRendererSource -ReferencedAssemblies $fpsRendererRefs -ErrorAction Stop
    }
    $script:FpsNativeGaugeReady = ('ScriptXVisual476.FluidFpsGauge' -as [type]) -ne $null
}
catch {
    Write-HsStartupLog ('FPS_VISUAL_RENDERER_FALLBACK: ' + ($_ | Out-String))
}

# Presentation consumes immutable snapshots. No disk I/O, process scans or statistics on the UI thread.
$script:Fps430LastRender = [datetime]::MinValue
$script:FpsVisualRateLogged = [datetime]::MinValue
$script:FpsGaugeLatestReal = 0.0
$script:FpsGaugeTargetValue = 0.0
$script:FpsGaugeVisualValue = 0.0
$script:FpsGaugeVelocity = 0.0
$script:FpsGaugeIsHeld = $false
$script:FpsGaugeExiting = $false
$script:FpsUiVisualIdentity = ''
$script:FpsUiIdentity = ''
$script:FpsUiSeries = ''
$script:FpsUiSequence = [long]-1
$script:FpsUiSnapshot = $null
$script:FpsUiLastMeasuredUtc = [datetime]::MinValue
$script:FpsUiLastLowMeasuredUtc = [datetime]::MinValue
$script:FpsUiMissingSinceUtc = [datetime]::MinValue
# Two different windows: short measurement gaps must not blink the UI, whereas
# a confirmed absence of the previous game must eventually release its data.
$script:FpsUiStaleGraceMs = 3500.0
$script:FpsUiTargetLostGraceMs = 8000.0
function Set-FpsLiveReading([double]$Value, [int]$GamePid) {
    if ($GamePid -le 0 -or $Value -le 0 -or [double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return }
    # Capture remains the authority. WPF animates the ring between genuine
    # samples; its display interpolation is not new measured game data.
    $script:FpsGaugeLatestReal = $Value
    $script:FpsGaugeTargetValue = $Value
    if ($script:FpsGaugeVisualValue -le 0.0) {
        # First genuine frame: initialize without a misleading zero-to-FPS count-up.
        $script:FpsGaugeVisualValue = $Value
        $script:FpsGaugeVelocity = 0.0
    }
    $script:FpsGaugeIsHeld = $false
    $script:FpsGaugeExiting = $false
    if ($null -ne $script:FpsFramePresenter) {
        $script:FpsFramePresenter.SetSample($Value)
    }
    elseif ($ui.FpsLive.Opacity -ne 1.0) { $ui.FpsLive.Opacity = 1.0 }
}
function Clear-FpsLiveReading {
    # Only clear when the game is actually gone/changed beyond the grace period.
    if ($null -ne $ui.FpsProcessBadge) { $ui.FpsProcessBadge.Opacity = 0.0 }
    if ($null -ne $ui.FpsProcessText) { $ui.FpsProcessText.Text = '' }
    if ($null -ne $ui.FpsStatusText) { $ui.FpsStatusText.Text = '' }
    $script:FpsGaugeLatestReal = 0.0
    $script:FpsGaugeTargetValue = 0.0
    $script:FpsGaugeVisualValue = 0.0
    $script:FpsGaugeVelocity = 0.0
    $script:FpsGaugeIsHeld = $false
    $script:FpsGaugeExiting = $false
    if ($null -ne $script:FpsFramePresenter) { $script:FpsFramePresenter.Reset(); return }
    if ($ui.FpsLive.Text -ne '') { $ui.FpsLive.Text = '' }
    if ($ui.FpsLive.Opacity -ne 1.0) { $ui.FpsLive.Opacity = 1.0 }
    $ui.FpsRingProgress.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
    $ui.FpsRingProgress.Opacity = 0.0
    $ui.FpsRingProgress.StrokeDashOffset = 43.93
    $script:FpsGaugeLevel = 0.0
    $script:FpsGaugePreviousValue = -1.0
    $script:FpsGaugeShownOpacity = 0.0
}
function Start-FpsGaugeExitToZero {
    # A visually smooth shutdown, triggered only by confirmed game exit.
    if ($null -ne $ui.FpsProcessBadge) { $ui.FpsProcessBadge.Opacity = 0.0 }
    if ($null -ne $ui.FpsProcessText) { $ui.FpsProcessText.Text = '' }
    if ($null -ne $ui.FpsStatusText) { $ui.FpsStatusText.Text = '' }
    # Never write interpolated values to the collector.
    if ($script:FpsGaugeExiting) { return }
    $script:FpsGaugeExiting = $true
    $script:FpsGaugeLatestReal = 0.0
    $script:FpsGaugeTargetValue = 0.0
    $script:FpsGaugeIsHeld = $false
    if ($null -ne $script:FpsFramePresenter) {
        $script:FpsFramePresenter.ExitToZero()
        return
    }
    # No additional timer: the existing hardware meter clock moves the arc.
    $script:FpsGaugeVelocity = 0.0
    if ($ui.FpsLive.Opacity -ne 1.0) { $ui.FpsLive.Opacity = 1.0 }
}
function Suspend-FpsLiveReading {
    if ($script:FpsGaugeExiting) { return }
    if ($null -ne $ui.FpsStatusText -and $ui.FpsStatusText.Text -ne 'Frame data paused') {
        $ui.FpsStatusText.Text = 'Frame data paused'
    }
    # A gap in measured presents is not a measured zero FPS. Keep the LAST
    # REAL sample, visually dimmed rather than blinking it off/on or claiming
    # a new live measurement. The ring NEVER animates through fake FPS samples.
    $script:FpsGaugeLatestReal = 0.0
    if ($null -ne $script:FpsFramePresenter) {
        $script:FpsFramePresenter.Hold()
        $script:FpsGaugeIsHeld = $script:FpsFramePresenter.IsHeld
        foreach ($name in @('FpsAvg','FpsLow','FpsPeak','FpsFrame')) {
            if ($ui[$name].Opacity -gt 0.86) { $ui[$name].Opacity = 0.86 }
        }
        return
    }
    # Freeze the last displayed measured reading; no fabricated motion during
    # a genuine absence of presents. A future measured frame can retarget it.
    $script:FpsGaugeTargetValue = $script:FpsGaugeVisualValue
    $script:FpsGaugeVelocity = 0.0
    $script:FpsGaugeIsHeld = $script:FpsGaugeVisualValue -gt 0
    if ($script:FpsGaugeIsHeld -and $ui.FpsLive.Opacity -ne 0.66) {
        $ui.FpsLive.Opacity = 0.66
    }
    foreach ($name in @('FpsAvg','FpsLow','FpsPeak','FpsFrame')) {
        if ($ui[$name].Opacity -gt 0.86) { $ui[$name].Opacity = 0.86 }
    }
}
function Reset-FpsStatistics {
    foreach ($name in @('FpsAvg','FpsLow','FpsPeak','FpsFrame')) {
        if ($ui[$name].Text -ne '') { $ui[$name].Text = '' }
        if ($ui[$name].Opacity -ne 1.0) { $ui[$name].Opacity = 1.0 }
    }
}
function Update-RealGameFps {
    if (-not $script:Fps433Ready) { Clear-FpsLiveReading; return }
    $frame = [ScriptXFps472.Engine]::GetLatest()
    $script:FpsUiSnapshot = $frame
    $now = [datetime]::UtcNow
    $isMeasured = ($frame.State -eq 'LIVE') -and ($frame.Fps -gt 0) -and ($frame.Pid -gt 0) -and (-not [string]::IsNullOrWhiteSpace([string]$frame.Identity))

    if ($isMeasured) {
        $script:FpsUiMissingSinceUtc = [datetime]::MinValue
        # Reset ONLY on a different verified game identity. Do not reset on a
        # PresentMon/RTSS fallback or swap-chain switch within the same game.
        if ($script:FpsUiIdentity -cne [string]$frame.Identity) {
            Clear-FpsLiveReading
            Reset-FpsStatistics
            $script:FpsUiIdentity = [string]$frame.Identity
            $script:FpsUiSeries = ''
            $script:FpsUiSequence = [long]-1
            $script:FpsUiLastMeasuredUtc = [datetime]::MinValue
            $script:FpsUiLastLowMeasuredUtc = [datetime]::MinValue
        }
        $series = '{0}/{1}/{2}' -f $frame.Identity, $frame.Source, $frame.Chain
        if ($series -cne $script:FpsUiSeries) {
            $script:FpsUiSeries = $series
            $script:FpsUiSequence = [long]-1
        }
        if ($script:FpsUiSequence -eq [long]$frame.Sequence) {
            # A repeated sampler snapshot is not a new frame. Keep current UI
            # untouched until a real sequence change, including stale dimming.
            if ($script:FpsUiLastMeasuredUtc -ne [datetime]::MinValue -and
                ($now - $script:FpsUiLastMeasuredUtc).TotalMilliseconds -ge $script:FpsUiStaleGraceMs) {
                Suspend-FpsLiveReading
            }
            return
        }
        $script:FpsUiSequence = [long]$frame.Sequence
        $script:FpsUiLastMeasuredUtc = $now
        Set-FpsLiveReading -Value ([double]$frame.Fps) -GamePid ([int]$frame.Pid)
        $script:FpsUiVisualIdentity = [string]$frame.Identity
        # Badge is sourced from the measured process, never a fixed game name.
        $gameName = [string]$frame.Game
        if (-not [string]::IsNullOrWhiteSpace($gameName)) {
            if ($ui.FpsProcessText.Text -cne $gameName) { $ui.FpsProcessText.Text = $gameName }
            if ($ui.FpsProcessBadge.Opacity -ne 1.0) { $ui.FpsProcessBadge.Opacity = 1.0 }
        }
        if ($ui.FpsStatusText.Text -cne 'Frame capture active') { $ui.FpsStatusText.Text = 'Frame capture active' }
        foreach ($name in @('FpsAvg','FpsLow','FpsPeak','FpsFrame')) { $ui[$name].Opacity = 1.0 }
        # RTSS has no per-frame distribution, so do not blank out a previously
        # measured PresentMon 1% LOW during brief source handovers.
        if ($frame.Avg -gt 0) {
            $value = if ($frame.Avg -lt 1) { '{0:0.######}' -f $frame.Avg } else { '{0:0.0}' -f $frame.Avg }
            if ($ui.FpsAvg.Text -cne $value) { $ui.FpsAvg.Text = $value }
        }
        if ($frame.Low -gt 0) {
            $value = if ($frame.Low -lt 1) { '{0:0.######}' -f $frame.Low } else { '{0:0.0}' -f $frame.Low }
            if ($ui.FpsLow.Text -cne $value) { $ui.FpsLow.Text = $value }
            $script:FpsUiLastLowMeasuredUtc = $now
        }
        # An RTSS fallback cannot supply per-frame 1% lows. Debounce its
        # staleness independently so rapid source handovers do not flash it.
        if ($ui.FpsLow.Text -ne '—' -and $script:FpsUiLastLowMeasuredUtc -ne [datetime]::MinValue -and
            ($now - $script:FpsUiLastLowMeasuredUtc).TotalMilliseconds -ge $script:FpsUiStaleGraceMs) {
            $ui.FpsLow.Opacity = 0.66
        }
        if ($frame.Peak -gt 0) {
            $value = '{0:0.0}' -f $frame.Peak
            if ($ui.FpsPeak.Text -cne $value) { $ui.FpsPeak.Text = $value }
        }
        if ($frame.FrameMs -gt 0) {
            $value = '{0:0.0}ms' -f $frame.FrameMs
            if ($ui.FpsFrame.Text -cne $value) { $ui.FpsFrame.Text = $value }
        }
        return
    }

    # Process-exit notifications from OS lifetime handles are authoritative.
    # Missing Present events or an Alt+Tab on their own never trigger this.
    if ($script:FpsUiIdentity -ne '' -and
        [string]$frame.ExitedIdentity -ceq $script:FpsUiIdentity) {
        Start-FpsGaugeExitToZero
        Reset-FpsStatistics
        $script:FpsUiIdentity = ''
        $script:FpsUiVisualIdentity = ''
        $script:FpsUiSeries = ''
        $script:FpsUiSequence = [long]-1
        $script:FpsUiLastMeasuredUtc = [datetime]::MinValue
        $script:FpsUiLastLowMeasuredUtc = [datetime]::MinValue
        $script:FpsUiMissingSinceUtc = [datetime]::MinValue
        return
    }

    # A real short gap (or a transient capture/session restart) is not proof
    # that the game closed. Keep the verified target and its last real stats.
    $sameGameAlive = $frame.TargetAlive -and ($script:FpsUiIdentity -ne '') -and ([string]$frame.Identity -ceq $script:FpsUiIdentity)
    if ($sameGameAlive) {
        $script:FpsUiMissingSinceUtc = [datetime]::MinValue
    } else {
        if ($script:FpsUiMissingSinceUtc -eq [datetime]::MinValue) {
            $script:FpsUiMissingSinceUtc = $now
        }
        if (($now - $script:FpsUiMissingSinceUtc).TotalMilliseconds -ge $script:FpsUiTargetLostGraceMs) {
            if ($script:FpsUiIdentity -ne '') {
                Clear-FpsLiveReading
                Reset-FpsStatistics
                $script:FpsUiIdentity = ''
                $script:FpsUiVisualIdentity = ''
                $script:FpsUiSeries = ''
                $script:FpsUiSequence = [long]-1
                $script:FpsUiLastMeasuredUtc = [datetime]::MinValue
                $script:FpsUiLastLowMeasuredUtc = [datetime]::MinValue
            }
            return
        }
    }
    if ($script:FpsUiLastMeasuredUtc -ne [datetime]::MinValue -and
        ($now - $script:FpsUiLastMeasuredUtc).TotalMilliseconds -ge $script:FpsUiStaleGraceMs) {
        Suspend-FpsLiveReading
    }
}
function Write-FpsUiDiagnostic {
    if (-not ($FpsDiagnostics -or $FpsProbe) -or $null -eq $script:FpsUiSnapshot -or -not $script:Fps433Ready) { return }
    try {
        $frame = $script:FpsUiSnapshot
        # Actual WPF dependency-property values (including the running visual animation), not a claim about screen pixels.
        $arcTarget = if ($null -ne $script:FpsFramePresenter) {
            [double](43.93 * (1.0 - [math]::Max(0.0, [math]::Min(1.0, $script:FpsFramePresenter.LatestTarget / 360.0))))
        } else { [double](43.93 * (1.0 - $script:FpsGaugeLevel)) }
        [ScriptXFps472.Engine]::RecordUi([string]$frame.Identity, [string]$frame.Source,
            [long]$frame.Sequence, [string]$frame.State, [double]$script:FpsGaugeLatestReal,
            [string]$ui.FpsLive.Text, [double]$arcTarget,
            [double]$ui.FpsRingProgress.StrokeDashOffset, [double]$ui.FpsRingProgress.Opacity)
    } catch {}
}

# Optional capture-only diagnostic: no tuning actions or GUI; run elevated for ETW access if needed.
# powershell.exe -NoProfile -File .\SCRIPT_X_FPS_4_70.ps1 -FpsProbe -FpsProbeSeconds 120
if ($FpsProbe) {
    Write-Output ('FPS engine compiled: ' + $script:Fps433Ready + '; elevated: ' + $script:IsElevated)
    Write-Output ('Diagnostic log: ' + $script:Fps433Log)
    if (-not $script:Fps433Ready) { Write-Output ('Compile diagnostics: ' + $script:StartupLog); return }
    Start-Fps433Engine
    try {
        for ($sample = 0; $sample -lt $FpsProbeSeconds; $sample++) {
            Start-Sleep -Seconds 1
            $frame = [ScriptXFps472.Engine]::GetLatest()
            Write-Output ('{0:HH:mm:ss} STATE={1} SOURCE={2} FPS={3:0.0} GAME={4} PID={5} AGE_MS={6:0} EVIDENCE={7} {8}' -f
                (Get-Date), $frame.State, $frame.Source, $frame.Fps, $frame.Game, $frame.Pid,
                $frame.FrameAgeMs, $frame.Evidence, [ScriptXFps472.Engine]::Diagnostic())
        }
    } finally { Stop-Fps433Engine }
    return
}

# All ordinary UI text uses the standard Windows Segoe UI font.
# Only the DASHBOARD / SYSTEM headlines use the private On Top font below.
$script:UiFontFamily = [Windows.Media.FontFamily]::new('Segoe UI')

# On Top Regular private font (c) The On Top Project Authors, SIL OFL 1.1.
# Used only for the stacked DASHBOARD and SYSTEM headlines. All other text stays Segoe UI.
# No system-wide installation, registry edits, or external font files required.
$script:DashboardFontFamily = [Windows.Media.FontFamily]::new('Segoe UI')
try {
    $fontFolder = Join-Path $env:LOCALAPPDATA 'ScriptX\Fonts\Dashboard'
    [void][IO.Directory]::CreateDirectory($fontFolder)
    $fontPath = Join-Path $fontFolder 'OnTop-Regular.ttf'
    $fontSha256 = 'EDF644EAC6227171ADEA37FB92AEB4ACF286F7A74D67B9CB03F0F882ABC3E969'
    $fontValid = ([IO.File]::Exists($fontPath) -and
        (Get-FileHash -LiteralPath $fontPath -Algorithm SHA256 -ErrorAction Stop).Hash -eq $fontSha256)
    if (-not $fontValid) {
        $b64 = @'
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
'@
        $zipBytes = [Convert]::FromBase64String(($b64 -replace '\s', ''))
        $msIn = [IO.MemoryStream]::new([byte[]]$zipBytes)
        $gz = [IO.Compression.GZipStream]::new($msIn, [IO.Compression.CompressionMode]::Decompress)
        $msOut = New-Object IO.MemoryStream
        try {
            $gz.CopyTo($msOut)
            $rawFont = $msOut.ToArray()
        }
        finally {
            $gz.Dispose()
            $msIn.Dispose()
            $msOut.Dispose()
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $actualSha = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$rawFont))).Replace('-', '') }
        finally { $sha.Dispose() }
        if ($actualSha -ne $fontSha256) { throw 'On Top bundled font data did not pass SHA-256.' }
        $tempPath = Join-Path $fontFolder (([guid]::NewGuid().ToString('N')) + '.tmp')
        try {
            [IO.File]::WriteAllBytes($tempPath, [byte[]]$rawFont)
            if ([IO.File]::Exists($fontPath)) { [IO.File]::Delete($fontPath) }
            [IO.File]::Move($tempPath, $fontPath)
        }
        finally { if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) } }
    }
    $fontFolderUri = [Uri]::new(($fontFolder.TrimEnd('\') + '\'), [UriKind]::Absolute)
    $candidate = [Windows.Media.FontFamily]::new($fontFolderUri, './#On Top')
    $face = [Windows.Media.Typeface]::new($candidate, [Windows.FontStyles]::Normal,
        [Windows.FontWeights]::Normal, [Windows.FontStretches]::Normal)
    $glyph = $null
    if (-not $face.TryGetGlyphTypeface([ref]$glyph)) { throw 'On Top glyph typeface unavailable.' }
    if ($null -eq $glyph -or -not $glyph.FontUri.IsFile -or
        [IO.Path]::GetFullPath($glyph.FontUri.LocalPath) -ine [IO.Path]::GetFullPath($fontPath)) {
        throw 'WPF selected a fallback font instead of the bundled On Top font.'
    }
    $script:DashboardFontFamily = $candidate
    Write-HsStartupLog ('DASHBOARD_FONT_EMBEDDED_OK: ' + $fontPath)
}
catch {
    Write-HsStartupLog ('DASHBOARD_FONT_EMBEDDED_FAILED: ' + $_.Exception.Message)
}


# Fixed runtime defaults (no Settings page, no saved settings file).
# Keep the keys required by the existing telemetry worker.
$script:Config = @{
    RefreshMs      = 2000
    PingTarget     = ''
    SelectedGpu    = ''
}

[xml]$markup = @'
<Window
 xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
 Title="SCRIPT X | 5.38 DEEP BLACK GRAPHITE FROSTED"
 Width="1040" Height="720" MinWidth="900" MinHeight="620"
 WindowStartupLocation="CenterScreen"
 WindowStyle="SingleBorderWindow" ResizeMode="CanMinimize" ShowInTaskbar="True" AllowsTransparency="False"
 Opacity="1" Background="#07070A" Foreground="#F5F5F7"
 ToolTipService.IsEnabled="False"
 FontSize="11"
 UseLayoutRounding="True"
 TextOptions.TextFormattingMode="Display"
 TextOptions.TextRenderingMode="ClearType">

 <!-- Non-layered WPF HWND: let Windows/DWM animate its real taskbar/minimize/restore.
      WindowChrome preserves custom visuals, system caption and frame semantics. -->
 <shell:WindowChrome.WindowChrome>
  <shell:WindowChrome CaptionHeight="38" ResizeBorderThickness="0"
                      GlassFrameThickness="0" CornerRadius="0"
                      UseAeroCaptionButtons="False"/>
 </shell:WindowChrome.WindowChrome>

 <Window.Resources>
  <Style TargetType="TextBlock">
   <Setter Property="TextWrapping" Value="Wrap"/>
   <Setter Property="SnapsToDevicePixels" Value="True"/>
   <Setter Property="TextOptions.TextFormattingMode" Value="Display"/>
   <Setter Property="TextOptions.TextRenderingMode" Value="ClearType"/>
   <Setter Property="TextOptions.TextHintingMode" Value="Fixed"/>
  </Style>

  <Style x:Key="Label" TargetType="TextBlock">
   <Setter Property="FontSize" Value="10"/>
   <Setter Property="Foreground" Value="#86868B"/>
  </Style>

  <!-- Unified 1-DIP satin hairline for all dashboard glass cards.
       The graphite-blue low-alpha stroke blends into the shared backdrop;
       whole-pixel thickness avoids fractional corner seams on Windows DPI. -->
  <Style x:Key="CardSurface" TargetType="Border">
   <Setter Property="CornerRadius" Value="18"/>
   <Setter Property="Padding" Value="16"/>
   <Setter Property="BorderThickness" Value="1"/>
   <Setter Property="BorderBrush">
    <Setter.Value>
     <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#259EACBE" Offset="0"/>
      <GradientStop Color="#18818FA3" Offset="0.48"/>
      <GradientStop Color="#0D667486" Offset="1"/>
     </LinearGradientBrush>
    </Setter.Value>
   </Setter>
   <Setter Property="Background" Value="#09ABBBD0"/>
   <Setter Property="UseLayoutRounding" Value="True"/>
   <Setter Property="SnapsToDevicePixels" Value="True"/>
  </Style>

  <!-- The hit surface stays in layout while the face and shadow lift together. -->
  <Style x:Key="CardHoverHost" TargetType="ContentControl">
   <Setter Property="Focusable" Value="False"/>
   <Setter Property="IsTabStop" Value="False"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ContentControl">
      <Grid Background="Transparent">
       <ContentPresenter x:Name="LiftedContent" SnapsToDevicePixels="True"/>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- FPS hero and five-field SHOW SPEC rail: glass, but NO hover motion. -->
  <Style x:Key="CardStatic" TargetType="Border" BasedOn="{StaticResource CardSurface}"/>

  <!-- The cached underlay draws only the part of the shadow outside the card. -->
  <DropShadowEffect x:Key="CardOuterShadow" Color="Black" Direction="270"
                    ShadowDepth="4" BlurRadius="12" Opacity="0.76"/>
  <Style x:Key="GlassLift" TargetType="Border">
   <Setter Property="CornerRadius" Value="18"/>
   <Setter Property="IsHitTestVisible" Value="False"/>
   <Setter Property="CacheMode"><Setter.Value>
    <BitmapCache RenderAtScale="1"/>
   </Setter.Value></Setter>
  </Style>

  <!-- Black text-shadows only: separate underlays for the 4 hardware cards. -->
  <Style x:Key="HardwareBlackTextShadow" TargetType="TextBlock">
   <Setter Property="Foreground" Value="#000000"/>
   <Setter Property="IsHitTestVisible" Value="False"/>
   <Setter Property="RenderTransform">
    <Setter.Value><TranslateTransform X="1.25" Y="1.6"/></Setter.Value>
   </Setter>
   <Setter Property="Effect">
    <Setter.Value>
     <DropShadowEffect Color="#000000" Direction="270" ShadowDepth="1.8"
                       BlurRadius="2.3" Opacity="1"/>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- A single translucent tint lets the window's dithered graphite show through. -->
  <SolidColorBrush x:Key="InsetGlass" Color="#06A4B5CA"/>
  <Style x:Key="Icon" TargetType="Border">
   <Setter Property="CornerRadius" Value="12"/>
   <Setter Property="Background" Value="{StaticResource InsetGlass}"/>
   <Setter Property="BorderThickness" Value="0"/>
  </Style>

  <SolidColorBrush x:Key="StorageTileText" Color="#F5F5F7"/>

  <LinearGradientBrush x:Key="NavSelectedGlass" StartPoint="0,0" EndPoint="1,0.75">
   <GradientStop Color="#120A84FF" Offset="0"/>
   <GradientStop Color="#18212834" Offset="0.38"/>
   <GradientStop Color="#27203248" Offset="1"/>
  </LinearGradientBrush>

  <Style TargetType="Button">
   <Setter Property="Foreground" Value="#A1A1A6"/>
   <Setter Property="Background" Value="Transparent"/>
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Padding" Value="12,12"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="Button">
      <Border x:Name="ButtonBorder"
              Background="{TemplateBinding Background}"
              CornerRadius="13"
              Padding="{TemplateBinding Padding}">
       <ContentPresenter
        HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
        VerticalAlignment="Center"/>
      </Border>
      <ControlTemplate.Triggers>
       <Trigger Property="IsMouseOver" Value="True">
        <Setter TargetName="ButtonBorder" Property="Background" Value="#26344B64"/>
        <Setter Property="Foreground" Value="#F5F5F7"/>
       </Trigger>
      </ControlTemplate.Triggers>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- Plain, low-overhead meters for Storage. -->
  <Style TargetType="ProgressBar">
   <Setter Property="Height" Value="5"/>
   <Setter Property="Minimum" Value="0"/>
   <Setter Property="Maximum" Value="100"/>
   <Setter Property="Foreground" Value="#85AFCB"/>
   <!-- Storage C:/D: same legible slate, slightly deeper toward the base. -->
   <Setter Property="Background"><Setter.Value>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
     <GradientStop Color="#2F3846" Offset="0"/>
     <GradientStop Color="#293240" Offset="0.50"/>
     <GradientStop Color="#232B38" Offset="1"/>
    </LinearGradientBrush>
   </Setter.Value></Setter>
   <Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="True">
       <Border Background="{TemplateBinding Background}" CornerRadius="3"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="3"/>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- Luminous glass meters: only the four hardware meters use an effect.
       PART_Indicator retains native WPF progress sizing; values are smoothed externally. -->
  <Style x:Key="GlowMeter" TargetType="ProgressBar">
   <Setter Property="Height" Value="8"/>
   <Setter Property="Minimum" Value="0"/>
   <Setter Property="Maximum" Value="100"/>
   <Setter Property="Foreground" Value="#8DBBE5"/>
   <!-- Deeper slate trough: a restrained three-stop gradient, not a black slot. -->
   <Setter Property="Background"><Setter.Value>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
     <GradientStop Color="#2D3644" Offset="0"/>
     <GradientStop Color="#25303C" Offset="0.44"/>
     <GradientStop Color="#1F2935" Offset="1"/>
    </LinearGradientBrush>
   </Setter.Value></Setter>
   <Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="False" UseLayoutRounding="False" ClipToBounds="False">
       <Border Background="{TemplateBinding Background}" CornerRadius="5"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="5" SnapsToDevicePixels="False" UseLayoutRounding="False">
        <Border.Effect>
         <DropShadowEffect Color="#74CBFF" BlurRadius="11"
                           ShadowDepth="0" Opacity="0.84"/>
        </Border.Effect>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- GPU progress: dedicated Gpu glow, not the CPU blue halo. -->
  <Style x:Key="GlowMeterGpu" TargetType="ProgressBar" BasedOn="{StaticResource GlowMeter}">
   <Setter Property="Foreground" Value="#65DFA6"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="False" UseLayoutRounding="False" ClipToBounds="False">
       <Border Background="{TemplateBinding Background}" CornerRadius="5"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="5"
               SnapsToDevicePixels="False" UseLayoutRounding="False">
        <Border.Effect>
         <DropShadowEffect Color="#75EABB" BlurRadius="11" ShadowDepth="0" Opacity="0.77"/>
        </Border.Effect>
        <Border BorderBrush="#38FFFFFF" BorderThickness="0,1,0,0"
                CornerRadius="5" Opacity="0.68"/>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- RAM progress: dedicated Ram glow, not the CPU blue halo. -->
  <Style x:Key="GlowMeterRam" TargetType="ProgressBar" BasedOn="{StaticResource GlowMeter}">
   <Setter Property="Foreground" Value="#C19AFF"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="False" UseLayoutRounding="False" ClipToBounds="False">
       <Border Background="{TemplateBinding Background}" CornerRadius="5"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="5"
               SnapsToDevicePixels="False" UseLayoutRounding="False">
        <Border.Effect>
         <DropShadowEffect Color="#C8AAFF" BlurRadius="11" ShadowDepth="0" Opacity="0.77"/>
        </Border.Effect>
        <Border BorderBrush="#38FFFFFF" BorderThickness="0,1,0,0"
                CornerRadius="5" Opacity="0.68"/>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- TEMP progress: dedicated Temp glow, not the CPU blue halo. -->
  <Style x:Key="GlowMeterTemp" TargetType="ProgressBar" BasedOn="{StaticResource GlowMeter}">
   <Setter Property="Foreground" Value="#FFB275"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="False" UseLayoutRounding="False" ClipToBounds="False">
       <Border Background="{TemplateBinding Background}" CornerRadius="5"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="5"
               SnapsToDevicePixels="False" UseLayoutRounding="False">
        <Border.Effect>
         <DropShadowEffect Color="#FFC08F" BlurRadius="11" ShadowDepth="0" Opacity="0.77"/>
        </Border.Effect>
        <Border BorderBrush="#38FFFFFF" BorderThickness="0,1,0,0"
                CornerRadius="5" Opacity="0.68"/>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <!-- Storage-only indicator glow; no shadow is ever applied to drive text. -->
  <Style x:Key="DiskGlowMeter" TargetType="ProgressBar">
   <Setter Property="Height" Value="6"/>
   <Setter Property="Minimum" Value="0"/>
   <Setter Property="Maximum" Value="100"/>
   <Setter Property="Foreground" Value="#7CC7FF"/>
   <!-- Storage C:/D: same legible slate, slightly deeper toward the base. -->
   <Setter Property="Background"><Setter.Value>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
     <GradientStop Color="#2F3846" Offset="0"/>
     <GradientStop Color="#293240" Offset="0.50"/>
     <GradientStop Color="#232B38" Offset="1"/>
    </LinearGradientBrush>
   </Setter.Value></Setter>
   <Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="True">
       <Border Background="{TemplateBinding Background}" CornerRadius="4"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="4">
        <Border.Effect>
         <DropShadowEffect Color="#73BFFE" ShadowDepth="0" BlurRadius="9" Opacity="0.72"/>
        </Border.Effect>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
  <Style x:Key="DiskWarnGlowMeter" TargetType="ProgressBar" BasedOn="{StaticResource DiskGlowMeter}">
   <Setter Property="Foreground" Value="#0A84FF"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="ProgressBar">
      <Grid x:Name="PART_Track" SnapsToDevicePixels="True">
       <Border Background="{TemplateBinding Background}" CornerRadius="4"/>
       <Border x:Name="PART_Indicator" HorizontalAlignment="Left"
               Background="{TemplateBinding Foreground}" CornerRadius="4">
        <Border.Effect>
         <DropShadowEffect Color="#FFA66D" ShadowDepth="0" BlurRadius="9" Opacity="0.72"/>
        </Border.Effect>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <DrawingImage x:Key="CpuArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <!-- CORE X: CPU die / round core / precision contact pins (24x24 WPF vector). -->
     <GeometryDrawing Brush="Transparent">
      <GeometryDrawing.Geometry>
       <RectangleGeometry Rect="0,0,24,24"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#74CBFF">
      <GeometryDrawing.Geometry>
       <GeometryGroup>
        <RectangleGeometry Rect="5,5,14,14" RadiusX="2.5" RadiusY="2.5"/>
        <RectangleGeometry Rect="7.9,2,2.2,3" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="13.9,2,2.2,3" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="7.9,19,2.2,3" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="13.9,19,2.2,3" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="2,7.9,3,2.2" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="2,13.9,3,2.2" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="19,7.9,3,2.2" RadiusX="1.1" RadiusY="1.1"/>
        <RectangleGeometry Rect="19,13.9,3,2.2" RadiusX="1.1" RadiusY="1.1"/>
       </GeometryGroup>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#263B56">
      <GeometryDrawing.Geometry>
       <RectangleGeometry Rect="8,8,8,8" RadiusX="1.2" RadiusY="1.2"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#E5EEFF">
      <GeometryDrawing.Geometry>
       <EllipseGeometry Center="12,12" RadiusX="2.4" RadiusY="2.4"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>

  <DrawingImage x:Key="GpuArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <!-- ECLIPSE NOIR: high-contrast 24x24 vector tuned for 17px and 15px display. -->
     <GeometryDrawing Brush="Transparent">
      <GeometryDrawing.Geometry>
       <RectangleGeometry Rect="0,0,24,24"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <!-- Bold mint-metal chassis and contacts: matches the Core X visual weight. -->
     <GeometryDrawing Brush="#8DD9C0"
      Geometry="M5,5 H19 Q21.2,5 21.2,7.2 V15.8 Q21.2,18 19,18 H5 Q2.8,18 2.8,15.8 V7.2 Q2.8,5 5,5 Z M6,18 H8.1 V21 H6 Z M10.9,18 H13 V21 H10.9 Z M15.8,18 H17.9 V21 H15.8 Z"/>
     <GeometryDrawing Brush="#19323A"
      Geometry="M5.3,7.2 H18.8 Q19.6,7.2 19.6,8 V15.2 Q19.6,15.9 18.8,15.9 H5.3 Q4.5,15.9 4.5,15.2 V8 Q4.5,7.2 5.3,7.2 Z"/>
     <!-- Dark metal track behind a bright crescent (not a tiny thin ring). -->
     <GeometryDrawing Brush="#53887B">
      <GeometryDrawing.Geometry>
       <EllipseGeometry Center="15.0,11.5" RadiusX="5.2" RadiusY="5.2"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#19323A">
      <GeometryDrawing.Geometry>
       <EllipseGeometry Center="15.0,11.5" RadiusX="3.05" RadiusY="3.05"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <!-- Bright eclipse arc with rounded ends: legible even at small sizes. -->
     <GeometryDrawing Brush="Transparent" Geometry="M12.0,8.6 A4.2,4.2 0 1 1 12.0,14.4">
      <GeometryDrawing.Pen>
       <Pen Brush="#B0F0D8" Thickness="2.1" StartLineCap="Round" EndLineCap="Round"/>
      </GeometryDrawing.Pen>
     </GeometryDrawing>
     <GeometryDrawing Brush="#E9FFF4">
      <GeometryDrawing.Geometry>
       <EllipseGeometry Center="15.0,11.5" RadiusX="1.4" RadiusY="1.4"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#A3D8C6"
      Geometry="M6,9.4 H8.7 V10.7 H6 Z M6,12.4 H8.7 V13.7 H6 Z"/>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>

  <DrawingImage x:Key="RamArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <GeometryDrawing Brush="Transparent">
      <GeometryDrawing.Geometry>
       <RectangleGeometry Rect="0,0,24,24"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#C8AAFF"
      Geometry="M3,6 H21 Q22,6 22,7 V16 H2 V7 Q2,6 3,6 Z M5,16 H7 V20 H5 Z M10,16 H12 V20 H10 Z M15,16 H17 V20 H15 Z M19,16 H21 V20 H19 Z"/>
     <GeometryDrawing Brush="#EBF5FF"
      Geometry="M5,8 H8 V14 H5 Z M10,8 H13 V14 H10 Z M15,8 H18 V14 H15 Z"/>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>

  <DrawingImage x:Key="TempArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <GeometryDrawing Brush="Transparent">
      <GeometryDrawing.Geometry>
       <RectangleGeometry Rect="0,0,24,24"/>
      </GeometryDrawing.Geometry>
     </GeometryDrawing>
     <GeometryDrawing Brush="#FFC08F"
      Geometry="M12,22 C6,22 3.5,17 5.5,12.5 C7,10 9.5,8 10,3 C14,6 14.5,10 15,11 C17.5,8.5 18,5.5 19,4 C23,10 22,16 18.5,19.5 C16.5,22 14,22 12,22 Z"/>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>
  <!-- Small local vector glyphs: no icon-font dependence for Show Spec. -->
  <DrawingImage x:Key="BoardArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <GeometryDrawing Brush="Transparent" Geometry="M0,0 H24 V24 H0 Z"/>
     <GeometryDrawing Brush="#B6B3FF" Geometry="M3,3 H21 V21 H3 Z"/>
     <GeometryDrawing Brush="#141628" Geometry="M5,5 H19 V19 H5 Z"/>
     <GeometryDrawing Brush="#DAD7FF" Geometry="M8,8 H14 V14 H8 Z M16,7 H18 V10 H16 Z M16,12 H18 V17 H16 Z M7,16 H13 V18 H7 Z"/>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>
  <DrawingImage x:Key="SystemArtwork">
   <DrawingImage.Drawing>
    <DrawingGroup>
     <GeometryDrawing Brush="Transparent" Geometry="M0,0 H24 V24 H0 Z"/>
     <GeometryDrawing Brush="#9CC8FF" Geometry="M3,5 L11,4 V11 H3 Z M13,4 L21,3 V11 H13 Z M3,13 H11 V20 L3,19 Z M13,13 H21 V21 L13,20 Z"/>
    </DrawingGroup>
   </DrawingImage.Drawing>
  </DrawingImage>
 </Window.Resources>

 <!-- One pixel-aligned matte perimeter; actual content is clipped separately to
      a rounded geometry. Fractional strokes + different radii caused edge seams. -->
 <Border x:Name="WindowFrame" BorderBrush="#16FFFFFF" BorderThickness="1"
         CornerRadius="18" ClipToBounds="True" SnapsToDevicePixels="True">
  <Grid x:Name="FrameContent" SnapsToDevicePixels="True">
   <Grid.Background>
    <SolidColorBrush Color="#07070A"/>
   </Grid.Background>
   <Grid.RowDefinitions>
    <RowDefinition Height="38"/>
    <RowDefinition Height="*"/>
   </Grid.RowDefinitions>

   <!-- Single static surface baked from the original graphite gradients. -->
   <Grid x:Name="FrameBackdrop" Grid.RowSpan="2" IsHitTestVisible="False"
         ClipToBounds="True" Background="#090B0E"/>

   <!-- The top 38 px are draggable chrome, but visually seamless with the page. -->
   <Grid x:Name="TitleDragArea" Background="Transparent">
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right"
                VerticalAlignment="Center" Margin="0,0,8,0"
                >
     <Button shell:WindowChrome.IsHitTestVisibleInChrome="True" x:Name="Minimize" Content="" FontFamily="Segoe MDL2 Assets"
             Width="32" Height="30" Padding="6"/>
     <Button shell:WindowChrome.IsHitTestVisibleInChrome="True" x:Name="Close" Content="" FontFamily="Segoe MDL2 Assets"
             Width="32" Height="30" Padding="6"/>
    </StackPanel>
    <!-- Continuous hairline under the header, with no separate header fill. -->
    <Border VerticalAlignment="Bottom" Height="1" IsHitTestVisible="False">
     <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
       <GradientStop Color="#00FFFFFF" Offset="0"/>
       <GradientStop Color="#1CFFFFFF" Offset="0.47"/>
       <GradientStop Color="#0CE7E9EF" Offset="0.84"/>
       <GradientStop Color="#00FFFFFF" Offset="1"/>
      </LinearGradientBrush>
     </Border.Background>
    </Border>
   </Grid>

   <Grid Grid.Row="1" Background="Transparent">
    <Grid.ColumnDefinitions>
     <ColumnDefinition Width="180"/>
     <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Seamless sidebar: shares the exact body background. -->
    <Border Background="Transparent" BorderThickness="0" Padding="0">
     <Viewbox Stretch="Uniform" StretchDirection="DownOnly">
      <DockPanel Margin="10,20,10,16" Width="156" Height="642">
       <ContentControl DockPanel.Dock="Bottom" Style="{StaticResource CardHoverHost}">
        <Border Style="{StaticResource CardSurface}"
                Padding="10" CornerRadius="15">
         <StackPanel>
          <StackPanel Orientation="Horizontal">
           <Border Width="30" Height="30" CornerRadius="15"
                   Background="#35445D78" BorderBrush="#28FFFFFF" BorderThickness="0.8">
            <TextBlock Text="X" HorizontalAlignment="Center"
                       VerticalAlignment="Center" FontSize="15"
                       Foreground="#DCECF6" x:Name="Avatar"/>
           </Border>
           <StackPanel Margin="9,2,0,0">
            <TextBlock Text="Your account" FontWeight="SemiBold" x:Name="ProfileName"/>
            <TextBlock Text="LOCAL PROFILE" Style="{StaticResource Label}"
                       FontSize="7" x:Name="ProfileMachine"/>
           </StackPanel>
          </StackPanel>
          <TextBlock Text="● LOCAL MONITOR" Style="{StaticResource Label}"
                     FontSize="7" Margin="0,12,0,0" x:Name="ProfileStatus"/>
         </StackPanel>
        </Border>
       </ContentControl>

       <StackPanel>
        <StackPanel Orientation="Horizontal" Margin="1,0,0,29">
         <Border Width="44" Height="44" Background="#35435B80"
                 CornerRadius="15" BorderThickness="1" BorderBrush="#30FFFFFF">
          <TextBlock Text="X" Foreground="#AFBDFF" FontSize="25"
                     FontFamily="Segoe UI" FontWeight="Bold" HorizontalAlignment="Center"
                     VerticalAlignment="Center"/>
         </Border>
         <StackPanel Margin="8,3,0,0" VerticalAlignment="Center">
          <TextBlock FontSize="18" FontWeight="Bold" FontFamily="Segoe UI" Foreground="#F3F3FF" TextWrapping="NoWrap">
           <Run Text="SCRIPT"/><Run Text="&#160;&#160;X" Foreground="#F5F5F7"/>
          </TextBlock>
         </StackPanel>
        </StackPanel>

        <TextBlock Text="M A I N" Style="{StaticResource Label}" FontSize="9.5" FontWeight="Bold"
                   Foreground="#86868B" Margin="7,0,0,11"/>
        <Button x:Name="Home" Tag="Home" Background="{StaticResource NavSelectedGlass}"
                Foreground="#DDE3ED" Margin="0,0,0,8" HorizontalContentAlignment="Left" FontSize="11" FontWeight="Bold" Padding="11,11">
         <StackPanel Orientation="Horizontal">
          <TextBlock Text="" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,12,0"/>
          <TextBlock Text="HOME" FontWeight="Bold" FontSize="11"/>
         </StackPanel>
        </Button>

        <TextBlock Text="T U N E"
                   Style="{StaticResource Label}" FontSize="9.5" FontWeight="Bold"
                   Foreground="#86868B" Margin="7,17,0,11"/>

        <Button x:Name="Boost" Tag="FPS TWEAK" Background="Transparent"
                Foreground="#9EAFBF" Margin="0,0,0,8" HorizontalContentAlignment="Left" FontSize="11" FontWeight="Bold" Padding="11,11">
         <StackPanel Orientation="Horizontal">
          <TextBlock Text="" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,12,0"/>
          <TextBlock Text="FPS TWEAK" FontWeight="Bold" FontSize="11"/>
         </StackPanel>
        </Button>

        <Button x:Name="Latency" Tag="Latency" Background="Transparent"
                Foreground="#9EAFBF" Margin="0,0,0,8" HorizontalContentAlignment="Left" FontSize="11" FontWeight="Bold" Padding="11,11">
         <StackPanel Orientation="Horizontal">
          <TextBlock Text="" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,12,0"/>
          <TextBlock Text="LATENCY" FontWeight="Bold" FontSize="11"/>
         </StackPanel>
        </Button>

        <Button x:Name="Network" Tag="Network" Background="Transparent"
                Foreground="#9EAFBF" Margin="0,0,0,8" HorizontalContentAlignment="Left" FontSize="11" FontWeight="Bold" Padding="11,11">
         <StackPanel Orientation="Horizontal">
          <TextBlock Text="" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,12,0"/>
          <TextBlock Text="NETWORK" FontWeight="Bold" FontSize="11"/>
         </StackPanel>
        </Button>

        <TextBlock Text="S Y S T E M"
                   Style="{StaticResource Label}" FontSize="9.5" FontWeight="Bold"
                   Foreground="#86868B" Margin="7,17,0,11"/>

        <Button x:Name="Cleanup" Tag="Clean Up" Background="Transparent"
                Foreground="#9EAFBF" Margin="0,0,0,8" HorizontalContentAlignment="Left" FontSize="11" FontWeight="Bold" Padding="11,11">
         <StackPanel Orientation="Horizontal">
          <TextBlock Text="" FontFamily="Segoe MDL2 Assets" FontSize="15" Margin="0,0,12,0"/>
          <TextBlock Text="CLEAN UP" FontWeight="Bold" FontSize="11"/>
         </StackPanel>
        </Button>

       </StackPanel>
      </DockPanel>
     </Viewbox>
    </Border>

    <!-- Restrained violet-blue divider, not a bright wall between panels. -->
    <Border Grid.Column="0" HorizontalAlignment="Right" Width="1"
            Margin="0,24,0,24" IsHitTestVisible="False">
     <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
       <GradientStop Color="#00FFFFFF" Offset="0"/>
       <GradientStop Color="#1CF1F5FF" Offset="0.26"/>
       <GradientStop Color="#22C2D8F5" Offset="0.52"/>
       <GradientStop Color="#18B3C6E4" Offset="0.78"/>
       <GradientStop Color="#00FFFFFF" Offset="1"/>
      </LinearGradientBrush>
     </Border.Background>
     <Border.Effect>
      <DropShadowEffect Color="#315E98D2" ShadowDepth="0" BlurRadius="8" Opacity="0.22"/>
     </Border.Effect>
    </Border>

    <!-- Same continuous body backdrop, only subtle violet-blue ambient glints. -->
    <Grid Grid.Column="1" Background="Transparent" ClipToBounds="True">

     <!-- At the standard 1040x720 size the 824x642 content now fits 1:1.
          This avoids fractional Viewbox scaling of live glyphs while hovered.
          At reduced window dimensions the existing responsive downscale remains. -->
     <Viewbox Margin="10,10,10,10" Stretch="Uniform" StretchDirection="DownOnly">
      <Grid Width="824" Height="642" x:Name="ContentPages">
       <Grid Width="824" Height="642" x:Name="HomePage">
       <Grid.RowDefinitions>
        <RowDefinition Height="68"/>
        <RowDefinition Height="12"/>
        <RowDefinition Height="284"/>
        <RowDefinition Height="12"/>
        <RowDefinition Height="160"/>
        <RowDefinition Height="12"/>
        <RowDefinition Height="84"/>
        <RowDefinition Height="0"/>
        <RowDefinition Height="10"/>
       </Grid.RowDefinitions>

       <!-- Header -->
       <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
         <ColumnDefinition Width="*"/>
         <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

         <StackPanel VerticalAlignment="Top" Margin="0,9,0,0">
          <!-- Both headings sit lower within their 68px row; no content overlap. -->
          <TextBlock x:Name="Connection" Text="" Visibility="Collapsed"/>
          <TextBlock x:Name="DashboardHeading" Text="DASHBOARD"
                     FontSize="23.5" FontWeight="Normal" Margin="0,0,0,0"
                     Foreground="#FFFFFF" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                     TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType"/>
          <TextBlock x:Name="SystemHeading" Text="SYSTEM"
                     FontSize="18" FontWeight="Normal" Margin="0,4,0,0"
                     Foreground="#F8FAFF" TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"
                     TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType"/>
         </StackPanel>

        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
         <Border Style="{StaticResource Icon}" Padding="10,6">
          <StackPanel>
           <TextBlock Text="U P T I M E" Style="{StaticResource Label}" FontSize="8" FontWeight="Bold"/>
           <TextBlock Text="—" FontSize="10"
                      Margin="0,3,0,0" x:Name="Uptime"/>
          </StackPanel>
         </Border>
         <Border Style="{StaticResource Icon}" Padding="10,6" Margin="5,0,0,0">
          <StackPanel>
           <TextBlock Text="L O C A L" Style="{StaticResource Label}" FontSize="8" FontWeight="Bold"/>
           <TextBlock x:Name="Clock" Text="00:00:00"
                      FontSize="10" Margin="0,3,0,0"/>
          </StackPanel>
         </Border>
        </StackPanel>
       </Grid>

       <!-- FPS and hardware cards -->
       <Grid x:Name="PerformanceRow" Grid.Row="2">
        <Grid.ColumnDefinitions>
         <ColumnDefinition Width="378"/>
         <ColumnDefinition Width="12"/>
         <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Border Style="{StaticResource GlassLift}"/>

         <Border Style="{StaticResource CardStatic}" Tag="FrostedStaticCard">

         <!-- Refined FPS card: original dark material, lightweight geometry and
              unchanged 8px native animation ring. Static elements only. -->
         <Grid ClipToBounds="False">
          <Grid.RowDefinitions>
           <RowDefinition Height="32"/>
           <RowDefinition Height="*"/>
           <RowDefinition Height="60"/>
          </Grid.RowDefinitions>

          <!-- Left-aligned badge: identity still comes from the active real game capture. -->
          <Grid Grid.Row="0" Margin="0,-7,0,0">
           <Border x:Name="FpsProcessBadge" HorizontalAlignment="Left"
                   MaxWidth="180" Opacity="0" CornerRadius="14" Padding="10,6"
                   BorderThickness="0.8" VerticalAlignment="Top" IsHitTestVisible="False">
            <Border.Background>
             <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
              <GradientStop Color="#30367AAC" Offset="0"/>
              <GradientStop Color="#1D142F52" Offset="1"/>
             </LinearGradientBrush>
            </Border.Background>
            <Border.BorderBrush>
             <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
              <GradientStop Color="#6675A6CF" Offset="0"/>
              <GradientStop Color="#24486C92" Offset="1"/>
             </LinearGradientBrush>
            </Border.BorderBrush>
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
             <Grid Width="9" Height="9" Margin="0,0,8,0" VerticalAlignment="Center">
              <Ellipse Fill="#245DE8B6" Width="9" Height="9"/>
              <Ellipse Fill="#6FF7C2" Width="5" Height="5"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
             </Grid>
             <TextBlock x:Name="FpsProcessText" Text="" MaxWidth="139"
                        FontSize="9.8" FontWeight="SemiBold" Foreground="#E7E1F3"
                        TextTrimming="CharacterEllipsis" TextWrapping="NoWrap"
                        VerticalAlignment="Center"/>
            </StackPanel>
           </Border>
          </Grid>

          <!-- All FPS geometry is anchored in ONE 220x172 Canvas. A Canvas
               keeps the radial tick marks concentric with the gauge, avoiding
               independent Path/Grid measure offsets and negative-coordinate clipping. -->
          <Grid Grid.Row="1" ClipToBounds="False" IsHitTestVisible="False">
           <Viewbox Width="230" Height="173" Stretch="Uniform"
                    HorizontalAlignment="Center" VerticalAlignment="Center"
                    SnapsToDevicePixels="False">
            <Canvas Width="220" Height="172" ClipToBounds="False"
                    SnapsToDevicePixels="False">
             <!-- v5.36 · Precision Etched Dial. A 5/12 major-minor tick rhythm
                  replaces the old dots, perimeter arc and top glint. Ticks sit
                  outside the live FPS gauge; no overlap or animation. -->
             <!-- Fine inset engraving: twelve short graphite-pearl indices. -->
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None" SnapsToDevicePixels="False"
                   Data="M 15.82,135.23 L 12.25,136.19 M 12.50,110.00 L 8.80,110.00 M 15.82,84.77 L 12.25,83.81 M 41.06,41.06 L 38.44,38.44 M 61.25,25.56 L 59.40,22.36 M 84.77,15.82 L 83.81,12.25 M 135.23,15.82 L 136.19,12.25 M 158.75,25.56 L 160.60,22.36 M 178.94,41.06 L 181.56,38.44 M 204.18,84.77 L 207.75,83.81 M 207.50,110.00 L 211.20,110.00 M 204.18,135.23 L 207.75,136.19"
                   Stroke="#BAC3D0" StrokeThickness="0.95" Opacity="0.48"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
             <!-- Major minute-style indices: a soft reflection plus a crisp tip. -->
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None" SnapsToDevicePixels="False"
                   Data="M 27.73,157.50 L 21.23,161.25 M 27.73,62.50 L 21.23,58.75 M 192.27,62.50 L 198.77,58.75 M 192.27,157.50 L 198.77,161.25"
                   Stroke="#F5F7FF" StrokeThickness="3.1" Opacity="0.105"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None" SnapsToDevicePixels="False"
                   Data="M 27.73,157.50 L 21.23,161.25 M 27.73,62.50 L 21.23,58.75 M 192.27,62.50 L 198.77,58.75 M 192.27,157.50 L 198.77,161.25"
                   Stroke="#D7DEE9" StrokeThickness="1.55" Opacity="0.74"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
             <!-- The crown index has a barely brighter platinum sheen, no dot. -->
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None" SnapsToDevicePixels="False"
                   Data="M 110.00,15.00 L 110.00,7.50"
                   Stroke="#F5F7FF" StrokeThickness="3.4" Opacity="0.14"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None" SnapsToDevicePixels="False"
                   Data="M 110.00,15.00 L 110.00,7.50"
                   Stroke="#F0F3FA" StrokeThickness="1.65" Opacity="0.82"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
             <!-- A single fixed 245-degree track, matching the live 43.93 dash scale. -->
             <Path Canvas.Left="0" Canvas.Top="0" Stretch="None"
                   Data="M 41,152 A 82,82 0 1 1 179,152"
                   Stroke="#505868" Opacity="0.80" StrokeThickness="8.6"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                   SnapsToDevicePixels="False"/>
             <!-- Glow like the hardware progress bars: the shadow belongs to
                  the SAME animated white-pearl segment, never a second fat arc. -->
             <Path x:Name="FpsRingProgress" Canvas.Left="0" Canvas.Top="0"
                   Stretch="None" Data="M 41,152 A 82,82 0 1 1 179,152"
                   StrokeThickness="8" StrokeDashArray="43.93 1000"
                   StrokeDashOffset="43.93" StrokeDashCap="Round"
                   StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                   Opacity="0" SnapsToDevicePixels="False">
              <Path.Effect>
               <DropShadowEffect Color="#C4E8FF" ShadowDepth="0"
                                 BlurRadius="11" Opacity="0.80"/>
              </Path.Effect>
              <Path.Stroke>
               <LinearGradientBrush StartPoint="0,0" EndPoint="0.85,1">
                <GradientStop Color="#FFFFFF" Offset="0"/>
                <GradientStop Color="#F4F5FF" Offset="0.19"/>
                <GradientStop Color="#DDDCFF" Offset="0.44"/>
                <GradientStop Color="#FFFDFE" Offset="0.68"/>
                <GradientStop Color="#E6DAF8" Offset="0.86"/>
                <GradientStop Color="#FFFFFF" Offset="1"/>
               </LinearGradientBrush>
              </Path.Stroke>
             </Path>
            </Canvas>
           </Viewbox>

            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center"
                        Margin="0,6,0,0" IsHitTestVisible="False">
             <StackPanel.RenderTransform>
              <TranslateTransform Y="2"/>
             </StackPanel.RenderTransform>
            <TextBlock x:Name="FpsLive" Text="" FontSize="38" FontWeight="Bold"
                       TextAlignment="Center" MinWidth="95" Foreground="#F8F5FF"
                       TextWrapping="NoWrap" TextOptions.TextFormattingMode="Ideal"
                       HorizontalAlignment="Center"/>
            <TextBlock x:Name="FpsUnitLabel" Text="F P S" FontSize="10.3" FontWeight="SemiBold"
                       Foreground="#9EE5FF" HorizontalAlignment="Center" Margin="0,-1,0,0">
             <TextBlock.Style>
              <Style TargetType="TextBlock">
               <Setter Property="Opacity" Value="1"/>
               <Style.Triggers>
                <DataTrigger Binding="{Binding Text, ElementName=FpsLive}" Value="">
                 <Setter Property="Opacity" Value="0"/>
                </DataTrigger>
               </Style.Triggers>
              </Style>
             </TextBlock.Style>
            </TextBlock>
            <!-- Internal status is retained for telemetry logic, never drawn. -->
            <TextBlock x:Name="FpsStatusText" Text="" Visibility="Collapsed"/>
           </StackPanel>
          </Grid>

          <!-- Soft integrated satin statistics rail: equal columns, unobtrusive
               vertical hairlines and generous spacing. No heavy black inset. -->
           <Border Grid.Row="2" Margin="0,4,0,0" CornerRadius="13"
                   Background="{StaticResource InsetGlass}" BorderThickness="0" SnapsToDevicePixels="True">
           <Border.RenderTransform>
            <TranslateTransform Y="8"/>
           </Border.RenderTransform>
           <Grid Margin="8,5,8,5">
            <Grid.ColumnDefinitions>
             <ColumnDefinition Width="*"/><ColumnDefinition Width="1"/>
             <ColumnDefinition Width="*"/><ColumnDefinition Width="1"/>
             <ColumnDefinition Width="*"/><ColumnDefinition Width="1"/>
             <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="1" Width="1" Margin="0,6,0,6">
             <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
               <GradientStop Color="#00877BA4" Offset="0"/>
               <GradientStop Color="#2A9FB5D2" Offset="0.5"/>
               <GradientStop Color="#00877BA4" Offset="1"/>
              </LinearGradientBrush>
             </Border.Background>
            </Border>
            <Border Grid.Column="3" Width="1" Margin="0,6,0,6" Background="#1C95A8C0"/>
            <Border Grid.Column="5" Width="1" Margin="0,6,0,6" Background="#1C95A8C0"/>
            <StackPanel Grid.Column="0" Margin="5,0" VerticalAlignment="Center">
             <TextBlock Text="AVG" Foreground="#CFC4DF" FontSize="9"
                        FontWeight="Bold" TextAlignment="Center"/>
             <TextBlock x:Name="FpsAvg" Text="" FontSize="15.8" FontWeight="SemiBold"
                        Foreground="#F2ECFA" TextAlignment="Center" Margin="0,5,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="2" Margin="5,0" VerticalAlignment="Center">
             <TextBlock Text="1% LOW" Foreground="#CFC4DF" FontSize="9"
                        FontWeight="Bold" TextAlignment="Center"/>
             <TextBlock x:Name="FpsLow" Text="" FontSize="15.8" FontWeight="SemiBold"
                        Foreground="#F2ECFA" TextAlignment="Center" Margin="0,5,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="4" Margin="5,0" VerticalAlignment="Center">
             <TextBlock Text="PEAK" Foreground="#CFC4DF" FontSize="9"
                        FontWeight="Bold" TextAlignment="Center"/>
             <TextBlock x:Name="FpsPeak" Text="" FontSize="15.8" FontWeight="SemiBold"
                        Foreground="#DCC6FA" TextAlignment="Center" Margin="0,5,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="6" Margin="4,0" VerticalAlignment="Center">
             <TextBlock Text="FRAME" Foreground="#CFC4DF" FontSize="9"
                        FontWeight="Bold" TextAlignment="Center"/>
             <TextBlock x:Name="FpsFrame" Text="" FontSize="13.5" FontWeight="SemiBold"
                        Foreground="#F2ECFA" TextWrapping="NoWrap"
                        TextAlignment="Center" Margin="0,6,0,0"/>
            </StackPanel>
           </Grid>
          </Border>
         </Grid>
        </Border>

        <Grid Grid.Column="2">
         <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="12"/>
          <ColumnDefinition Width="*"/>
         </Grid.ColumnDefinitions>
         <Grid.RowDefinitions>
          <RowDefinition Height="*"/>
          <RowDefinition Height="*"/>
         </Grid.RowDefinitions>

         <!-- CPU -->
         <Grid Grid.Row="0" Grid.Column="0" Margin="0,0,0,8">
          <ContentControl Style="{StaticResource CardHoverHost}">
           <Grid>
            <Border Style="{StaticResource GlassLift}"/>

            <Border Style="{StaticResource CardSurface}" Effect="{x:Null}" Padding="14,12">
            <Grid>
             <Grid.RowDefinitions>
              <RowDefinition Height="39"/>
              <RowDefinition Height="7"/>
              <RowDefinition Height="0"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="10"/>
             </Grid.RowDefinitions>
             <Grid>
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="38"/>
               <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Width="33" Height="33" CornerRadius="11"
                      HorizontalAlignment="Left" Background="#1A2239">
               <Image Source="{StaticResource CpuArtwork}" Width="17" Height="17"
                      Stretch="Uniform" UseLayoutRounding="False"
                      SnapsToDevicePixels="False"
                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0">
               <Grid>
                <!-- Black offset-shadow underlay; foreground title remains ClearType/sharp. -->
                <TextBlock Text="CPU" FontSize="16" FontWeight="Bold"
                           Style="{StaticResource HardwareBlackTextShadow}" TextWrapping="NoWrap"/>
                <TextBlock Text="CPU" FontSize="16" FontWeight="Bold"
                           Foreground="#F5F3FF" TextWrapping="NoWrap"/>
               </Grid>
               <TextBlock x:Name="CpuDetail" Text="DETECTING HARDWARE" FontSize="9.3"
                          FontWeight="SemiBold" Foreground="#B6C8E3"
                          Margin="0,2,0,0" TextWrapping="NoWrap"
                          TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Grid>



             <Grid Grid.Row="3" Margin="0,4,0,4">
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="*"/>
               <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Grid Grid.Column="0" VerticalAlignment="Center">
               <TextBlock Text="{Binding Text, ElementName=CpuValue}" FontSize="24"
                          FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"
                          Style="{StaticResource HardwareBlackTextShadow}"/>
               <TextBlock x:Name="CpuValue" Text="—" FontSize="24"
                         FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"/>
              </Grid>
              <Border Grid.Column="1" Background="#382A415A" Padding="9,4"
                      CornerRadius="9" VerticalAlignment="Center" Margin="8,0,0,0">
               <Grid>

  <TextBlock x:Name="CpuBadge" Text="—" FontSize="9.5"
                           FontWeight="Bold" Foreground="#67C7FF" TextWrapping="NoWrap"/>
               </Grid>
              </Border>
             </Grid>
             <ProgressBar x:Name="CpuBars" Grid.Row="4" Value="0"
                          Style="{StaticResource GlowMeter}" Foreground="#6AC8FF"/>
            </Grid>
            </Border>
           </Grid>
          </ContentControl>
         </Grid>

         <!-- GPU -->
         <Grid Grid.Row="0" Grid.Column="2" Margin="0,0,0,8">
          <ContentControl Style="{StaticResource CardHoverHost}">
           <Grid>
            <Border Style="{StaticResource GlassLift}"/>

            <Border Style="{StaticResource CardSurface}" Effect="{x:Null}" Padding="14,12">
            <Grid>
             <Grid.RowDefinitions>
              <RowDefinition Height="39"/>
              <RowDefinition Height="7"/>
              <RowDefinition Height="0"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="10"/>
             </Grid.RowDefinitions>
             <Grid>
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="38"/>
               <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Width="33" Height="33" CornerRadius="11"
                      HorizontalAlignment="Left" Background="#193A30">
               <Image Source="{StaticResource GpuArtwork}" Width="17" Height="17"
                      Stretch="Uniform" UseLayoutRounding="False"
                      SnapsToDevicePixels="False"
                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0">
               <Grid>
                <!-- Black offset-shadow underlay; foreground title remains ClearType/sharp. -->
                <TextBlock Text="GPU" FontSize="16" FontWeight="Bold"
                           Style="{StaticResource HardwareBlackTextShadow}" TextWrapping="NoWrap"/>
                <TextBlock Text="GPU" FontSize="16" FontWeight="Bold"
                           Foreground="#F5F3FF" TextWrapping="NoWrap"/>
               </Grid>
               <TextBlock x:Name="GpuName" Text="DETECTING HARDWARE" FontSize="9.3"
                          FontWeight="SemiBold" Foreground="#B5DBCF"
                          Margin="0,2,0,0" TextWrapping="NoWrap"
                          TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Grid>



             <Grid Grid.Row="3" Margin="0,4,0,4">
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="*"/>
               <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Grid Grid.Column="0" VerticalAlignment="Center">
               <TextBlock Text="{Binding Text, ElementName=GpuValue}" FontSize="24"
                          FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"
                          Style="{StaticResource HardwareBlackTextShadow}"/>
               <TextBlock x:Name="GpuValue" Text="—" FontSize="24"
                         FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"/>
              </Grid>
              <Border Grid.Column="1" Background="#34253D38" Padding="9,4"
                      CornerRadius="9" VerticalAlignment="Center" Margin="8,0,0,0">
               <Grid>

  <TextBlock x:Name="GpuBadge" Text="—" FontSize="9.5"
                           FontWeight="Bold" Foreground="#67EEB2" TextWrapping="NoWrap"/>
               </Grid>
              </Border>
             </Grid>
             <ProgressBar x:Name="GpuBars" Grid.Row="4" Value="0"
                          Style="{StaticResource GlowMeterGpu}" Foreground="#65DFA6"/>
            </Grid>
            </Border>
           </Grid>
          </ContentControl>
         </Grid>

         <!-- RAM -->
         <Grid Grid.Row="1" Grid.Column="0" Margin="0,8,0,0">
          <ContentControl Style="{StaticResource CardHoverHost}">
           <Grid>
            <Border Style="{StaticResource GlassLift}"/>

            <Border Style="{StaticResource CardSurface}" Effect="{x:Null}" Padding="14,12">
            <Grid>
             <Grid.RowDefinitions>
              <RowDefinition Height="39"/>
              <RowDefinition Height="7"/>
              <RowDefinition Height="0"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="10"/>
             </Grid.RowDefinitions>
             <Grid>
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="38"/>
               <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Width="33" Height="33" CornerRadius="11"
                      HorizontalAlignment="Left" Background="#231A38">
               <Image Source="{StaticResource RamArtwork}" Width="17" Height="17"
                      Stretch="Uniform" UseLayoutRounding="False"
                      SnapsToDevicePixels="False"
                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0">
               <Grid>
                <!-- Black offset-shadow underlay; foreground title remains ClearType/sharp. -->
                <TextBlock Text="RAM" FontSize="16" FontWeight="Bold"
                           Style="{StaticResource HardwareBlackTextShadow}" TextWrapping="NoWrap"/>
                <TextBlock Text="RAM" FontSize="16" FontWeight="Bold"
                           Foreground="#F5F3FF" TextWrapping="NoWrap"/>
               </Grid>
               <TextBlock x:Name="RamDetail" Text="DETECTING HARDWARE" FontSize="9.3"
                          FontWeight="SemiBold" Foreground="#CDBAF1"
                          Margin="0,2,0,0" TextWrapping="NoWrap"
                          TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Grid>



             <Grid Grid.Row="3" Margin="0,4,0,4">
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="*"/>
               <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Grid Grid.Column="0" VerticalAlignment="Center">
               <TextBlock Text="{Binding Text, ElementName=RamValue}" FontSize="24"
                          FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"
                          Style="{StaticResource HardwareBlackTextShadow}"/>
               <TextBlock x:Name="RamValue" Text="—" FontSize="24"
                         FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"/>
              </Grid>
              <Border Grid.Column="1" Background="#383E3351" Padding="9,4"
                      CornerRadius="9" VerticalAlignment="Center" Margin="8,0,0,0">
               <Grid>

  <TextBlock x:Name="RamBadge" Text="—" FontSize="9.5"
                           FontWeight="Bold" Foreground="#C9A1FF" TextWrapping="NoWrap"/>
               </Grid>
              </Border>
             </Grid>
             <ProgressBar x:Name="RamBars" Grid.Row="4" Value="0"
                          Style="{StaticResource GlowMeterRam}" Foreground="#C19AFF"/>
            </Grid>
            </Border>
           </Grid>
          </ContentControl>
         </Grid>

         <!-- GPU temperature -->
         <Grid Grid.Row="1" Grid.Column="2" Margin="0,8,0,0">
          <ContentControl Style="{StaticResource CardHoverHost}">
           <Grid>
            <Border Style="{StaticResource GlassLift}"/>

            <Border Style="{StaticResource CardSurface}" Effect="{x:Null}" Padding="14,12">
            <Grid>
             <Grid.RowDefinitions>
              <RowDefinition Height="39"/>
              <RowDefinition Height="7"/>
              <RowDefinition Height="0"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="10"/>
             </Grid.RowDefinitions>
             <Grid>
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="38"/>
               <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Width="33" Height="33" CornerRadius="11"
                      HorizontalAlignment="Left" Background="#322216">
               <Image Source="{StaticResource TempArtwork}" Width="17" Height="17"
                      Stretch="Uniform" UseLayoutRounding="False"
                      SnapsToDevicePixels="False"
                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="2,0,0,0">
               <Grid>
                <!-- Black offset-shadow underlay; foreground title remains ClearType/sharp. -->
                <TextBlock Text="TEMP" FontSize="16" FontWeight="Bold"
                           Style="{StaticResource HardwareBlackTextShadow}" TextWrapping="NoWrap"/>
                <TextBlock Text="TEMP" FontSize="16" FontWeight="Bold"
                           Foreground="#F5F3FF" TextWrapping="NoWrap"/>
               </Grid>
               <TextBlock x:Name="TempDetail" Text="DETECTING HARDWARE" FontSize="9.3"
                          FontWeight="SemiBold" Foreground="#F0C7A5"
                          Margin="0,2,0,0" TextWrapping="NoWrap"
                          TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Grid>



             <Grid Grid.Row="3" Margin="0,4,0,4">
              <Grid.ColumnDefinitions>
               <ColumnDefinition Width="*"/>
               <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Grid Grid.Column="0" VerticalAlignment="Center">
               <TextBlock Text="{Binding Text, ElementName=TempValue}" FontSize="24"
                          FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"
                          Style="{StaticResource HardwareBlackTextShadow}"/>
               <TextBlock x:Name="TempValue" Text="—" FontSize="24"
                         FontWeight="Bold" VerticalAlignment="Center" TextWrapping="NoWrap"/>
              </Grid>
              <Border Grid.Column="1" Background="#38443A2E" Padding="9,4"
                      CornerRadius="9" VerticalAlignment="Center" Margin="8,0,0,0">
               <Grid>

  <TextBlock x:Name="TempBadge" Text="—" FontSize="9.5"
                           FontWeight="Bold" Foreground="#FFB476" TextWrapping="NoWrap"/>
               </Grid>
              </Border>
             </Grid>
             <ProgressBar x:Name="TempBars" Grid.Row="4" Value="0"
                          Style="{StaticResource GlowMeterTemp}" Foreground="#FFB275"/>
            </Grid>
            </Border>
           </Grid>
          </ContentControl>
         </Grid>

        </Grid>
       </Grid>

       <!-- Health / Storage / Network -->
       <Grid Grid.Row="4">
        <Grid.ColumnDefinitions>
         <ColumnDefinition Width="1.2*"/>
         <ColumnDefinition Width="10"/>
         <ColumnDefinition Width="*"/>
         <ColumnDefinition Width="10"/>
         <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <ContentControl Style="{StaticResource CardHoverHost}">
         <Grid>
          <Border Style="{StaticResource GlassLift}"/>

          <Border Style="{StaticResource CardSurface}" Padding="13,12,13,5">
           <Grid>
            <Grid.RowDefinitions>
             <RowDefinition Height="Auto"/>
             <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <TextBlock Text="SYSTEM HEALTH" FontSize="15" Foreground="#F5F5F7" FontWeight="Bold"/>
            <Grid Grid.Row="1">
             <Grid.ColumnDefinitions>
              <ColumnDefinition Width="116"/>
              <ColumnDefinition Width="*"/>
             </Grid.ColumnDefinitions>
             <!-- Scale the ring and its glow together within the space below the heading. -->
             <Viewbox Stretch="Uniform" StretchDirection="DownOnly"
                      HorizontalAlignment="Left" VerticalAlignment="Center">
              <Grid Width="126" Height="126">
               <Grid Width="102" Height="102" Margin="12">
                <Ellipse Stroke="#28353D" StrokeThickness="5"/>
                <Path x:Name="HealthArc" Canvas.Left="0" Stretch="None"
                      Data="M51,2.5 A48.5,48.5 0 0 1 51,99.5 A48.5,48.5 0 0 1 51,2.5"
                      Stroke="#39D6A4" StrokeThickness="5" StrokeDashArray="60.94689748 68"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeDashCap="Round">
                 <Path.Style>
                  <Style TargetType="Path">
                   <Style.Triggers>
                    <Trigger Property="Canvas.Left" Value="0">
                     <Setter Property="Visibility" Value="Hidden"/>
                    </Trigger>
                   </Style.Triggers>
                  </Style>
                 </Path.Style>
                 <Path.Effect><DropShadowEffect Color="{Binding Stroke.Color, ElementName=HealthArc}"
                               BlurRadius="12" ShadowDepth="0" Opacity="0.90"/></Path.Effect>
                </Path>
                <TextBlock Text="—" FontSize="22" FontWeight="Bold" Foreground="#F5F5F7"
                           HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center"
                           x:Name="HealthValue"/>
               </Grid>
              </Grid>
             </Viewbox>
             <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="16,0,0,0">
              <TextBlock Text="CONNECTING" Foreground="#0A84FF" FontWeight="Bold"
                         FontSize="11.5" ToolTipService.IsEnabled="True" x:Name="HealthState"
                         TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              <TextBlock Text="Temperature —" Foreground="#A1A1A6" FontSize="12"
                         Margin="0,9,0,0" ToolTipService.IsEnabled="True" x:Name="HealthOne"
                         TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              <TextBlock Text="Memory —" Foreground="#A1A1A6" FontSize="12"
                         Margin="0,8,0,0" ToolTipService.IsEnabled="True" x:Name="HealthTwo"
                         TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              <TextBlock Text="Disk / errors —" Foreground="#A1A1A6" FontSize="12"
                         Margin="0,8,0,0" ToolTipService.IsEnabled="True" x:Name="HealthThree"
                         TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
             </StackPanel>
            </Grid>
           </Grid>
          </Border>
         </Grid>
        </ContentControl>

        <ContentControl Grid.Column="2" Style="{StaticResource CardHoverHost}">
         <Grid>
          <Border Style="{StaticResource GlassLift}"/>

          <Border Style="{StaticResource CardSurface}" Padding="13">
           <StackPanel>
            <TextBlock Text="STORAGE" FontSize="15" Foreground="#F5F5F7" FontWeight="Bold"/>
            <StackPanel x:Name="Storage" Margin="0,9,0,0"/>
           </StackPanel>
          </Border>
         </Grid>
        </ContentControl>

        <ContentControl Grid.Column="4" Style="{StaticResource CardHoverHost}">
         <Grid>
          <Border Style="{StaticResource GlassLift}"/>

          <Border Style="{StaticResource CardSurface}" Padding="13">
           <StackPanel>
            <TextBlock Text="NETWORK" FontSize="15" Foreground="#F5F5F7" x:Name="NetHeading" FontWeight="Bold"/>
            <TextBlock FontSize="27" Foreground="#F4F6FF" FontWeight="Bold" Margin="0,7,0,7"
                       x:Name="NetPing" Text="—"/>
            <UniformGrid Columns="3">
             <Border Style="{StaticResource Icon}" Padding="5,7" Margin="0,0,5,0">
              <StackPanel>
               <TextBlock Text="↓ DOWN" Style="{StaticResource Label}" FontSize="9" FontWeight="Bold"/>
               <TextBlock Text="—" FontSize="11" Foreground="#E6EDFC" FontWeight="SemiBold" Margin="0,5,0,0" x:Name="NetDown"
                          TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Border>
             <Border Style="{StaticResource Icon}" Padding="5,7" Margin="0,0,5,0">
              <StackPanel>
               <TextBlock Text="↑ UP" Style="{StaticResource Label}" FontSize="9" FontWeight="Bold"/>
               <TextBlock Text="—" FontSize="11" Foreground="#E6EDFC" FontWeight="SemiBold" Margin="0,5,0,0" x:Name="NetUp"
                          TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Border>
             <Border Style="{StaticResource Icon}" Padding="5,7">
              <StackPanel>
               <TextBlock Text="JITTER" Style="{StaticResource Label}" FontSize="9" FontWeight="Bold"/>
               <TextBlock Text="—" FontSize="11" Foreground="#E6EDFC" FontWeight="SemiBold" Margin="0,5,0,0" ToolTip="Mean change between consecutive ping replies (up to 10 samples)." x:Name="NetJitter"
                          TextWrapping="NoWrap" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
             </Border>
            </UniformGrid>
           </StackPanel>
          </Border>
         </Grid>
        </ContentControl>
       </Grid>

       <!-- Specifications: static frosted five-field spec rail; no hover. -->
       <Border Style="{StaticResource GlassLift}" Grid.Row="6"/>

       <Border Style="{StaticResource CardStatic}" Padding="7,8" Grid.Row="6" Tag="FrostedStaticCard">
        <UniformGrid Columns="5" Margin="0,0,0,0">
         <Border BorderThickness="0,0,1,0" BorderBrush="#12DCE5F7" Padding="8,0,8,0">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch">
           <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Image Source="{StaticResource CpuArtwork}" Width="15" Height="15"
                   Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Text="PROCESSOR" Style="{StaticResource Label}"
                       FontSize="9.5" FontWeight="Bold" TextWrapping="NoWrap"
                       VerticalAlignment="Center"/>
           </StackPanel>
           <TextBlock x:Name="SpecCpu" Text="—" TextAlignment="Center" HorizontalAlignment="Stretch" FontSize="11.5" FontWeight="SemiBold"
                      Foreground="#E7EAF5" Margin="0,10,0,0" TextWrapping="NoWrap"
                      TextTrimming="None"/>
          </StackPanel>
         </Border>
         <Border BorderThickness="0,0,1,0" BorderBrush="#12DCE5F7" Padding="8,0,8,0">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch">
           <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Image Source="{StaticResource GpuArtwork}" Width="15" Height="15"
                   Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Text="GRAPHICS" Style="{StaticResource Label}"
                       FontSize="9.5" FontWeight="Bold" TextWrapping="NoWrap"
                       VerticalAlignment="Center"/>
           </StackPanel>
           <TextBlock x:Name="SpecGpu" Text="—" TextAlignment="Center" HorizontalAlignment="Stretch" FontSize="11.5" FontWeight="SemiBold"
                      Foreground="#E7EAF5" Margin="0,10,0,0" TextWrapping="NoWrap"
                      TextTrimming="None"/>
          </StackPanel>
         </Border>
         <Border BorderThickness="0,0,1,0" BorderBrush="#12DCE5F7" Padding="8,0,8,0">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch">
           <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Image Source="{StaticResource RamArtwork}" Width="15" Height="15"
                   Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Text="MEMORY" Style="{StaticResource Label}"
                       FontSize="9.5" FontWeight="Bold" TextWrapping="NoWrap"
                       VerticalAlignment="Center"/>
           </StackPanel>
           <TextBlock x:Name="SpecRam" Text="—" TextAlignment="Center" HorizontalAlignment="Stretch" FontSize="11.5" FontWeight="SemiBold"
                      Foreground="#E7EAF5" Margin="0,10,0,0" TextWrapping="NoWrap"
                      TextTrimming="None"/>
          </StackPanel>
         </Border>
         <Border BorderThickness="0,0,1,0" BorderBrush="#12DCE5F7" Padding="8,0,8,0">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch">
           <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Image Source="{StaticResource BoardArtwork}" Width="15" Height="15"
                   Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Text="MOTHERBOARD" Style="{StaticResource Label}"
                       FontSize="9.5" FontWeight="Bold" TextWrapping="NoWrap"
                       VerticalAlignment="Center"/>
           </StackPanel>
           <TextBlock x:Name="SpecBoard" Text="—" TextAlignment="Center" HorizontalAlignment="Stretch" FontSize="11.5" FontWeight="SemiBold"
                      Foreground="#E7EAF5" Margin="0,10,0,0" TextWrapping="NoWrap"
                      TextTrimming="None"/>
          </StackPanel>
         </Border>
         <Border BorderThickness="0" BorderBrush="#12DCE5F7" Padding="8,0,8,0">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch">
           <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Image Source="{StaticResource SystemArtwork}" Width="15" Height="15"
                   Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Text="SYSTEM" Style="{StaticResource Label}"
                       FontSize="9.5" FontWeight="Bold" TextWrapping="NoWrap"
                       VerticalAlignment="Center"/>
           </StackPanel>
           <TextBlock x:Name="SpecOS" Text="—" TextAlignment="Center" HorizontalAlignment="Stretch" FontSize="11.5" FontWeight="SemiBold"
                      Foreground="#E7EAF5" Margin="0,10,0,0" TextWrapping="NoWrap"
                      TextTrimming="None"/>
          </StackPanel>
         </Border>
        </UniformGrid>
       </Border>

       <TextBlock Text="" Foreground="#76899A" FontSize="9" x:Name="ProviderStatus" Grid.Row="8" Visibility="Collapsed"/>
       </Grid>
       <!-- Empty placeholder for FPS TWEAK / LATENCY / NETWORK / CLEAN UP.
            The shared window background stays visible, with no modal popup. -->
       <Grid x:Name="BlankPage" Visibility="Collapsed" Background="Transparent"/>
      </Grid>
     </Viewbox>
    </Grid>
   </Grid>
  </Grid>
 </Border>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load(
    (New-Object Xml.XmlNodeReader $markup)
)
$window.FontFamily = $script:UiFontFamily

# Load the dithered background once for the window and its translucent cards.
$backdropBytes = [Convert]::FromBase64String(@'
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
rkJggg==
'@
)
$backdropStream = [IO.MemoryStream]::new($backdropBytes)
try {
    $bitmap = [Windows.Media.Imaging.BitmapImage]::new()
    $bitmap.BeginInit()
    $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.StreamSource = $backdropStream
    $bitmap.EndInit()
    $bitmap.Freeze()
    $backdropBrush = [Windows.Media.ImageBrush]::new($bitmap)
    $backdropBrush.Stretch = [Windows.Media.Stretch]::Fill
    $backdropBrush.Freeze()
    $backdropSurface = $window.FindName('FrameBackdrop')
    $backdropSurface.Background = $backdropBrush
}
finally {
    $backdropStream.Dispose()
    $backdropBytes = $null
}

# Match the inner window clip to the 18px outer WindowFrame radius (minus
# the 1px border): no square corner patches or uneven inner rounding.
$frameClip = New-Object Windows.Media.RectangleGeometry
$frameClip.RadiusX = 17
$frameClip.RadiusY = 17
$frameContent = $window.FindName('FrameContent')
$frameContent.Clip = $frameClip

$script:CardShadowsInitialized = $false

function Set-CardShadowClip($hostBorder) {
    $w = $hostBorder.ActualWidth
    $h = $hostBorder.ActualHeight
    if ($w -le 0 -or $h -le 0) {
        $hostBorder.Clip = [Windows.Media.Geometry]::Empty
        return
    }
    # Clip the parent after its child's shadow effect has been drawn.
    $outer = [Windows.Rect]::new(-20.0, -20.0, ($w + 40.0), ($h + 40.0))
    $face = [Windows.Rect]::new(0.0, 0.0, $w, $h)
    $clip = [Windows.Media.GeometryGroup]::new()
    $clip.FillRule = [Windows.Media.FillRule]::EvenOdd
    $clip.Children.Add([Windows.Media.RectangleGeometry]::new($outer))
    $radius = $hostBorder.CornerRadius.TopLeft
    $clip.Children.Add([Windows.Media.RectangleGeometry]::new($face, $radius, $radius))
    $clip.Freeze()
    $hostBorder.Clip = $clip
}

# Move the entire presenter by whole screen pixels, including any outer Viewbox scale.
function Set-CardHoverLift($card, [bool]$raised) {
    $source = [Windows.PresentationSource]::FromVisual($card)
    if (-not $source -or -not $source.CompositionTarget) { return }
    $face = $card.Template.FindName('LiftedContent', $card)
    if (-not $face) { return }

    $toRoot = $card.TransformToAncestor($source.RootVisual)
    $p0 = $toRoot.Transform([Windows.Point]::new(0, 0))
    $p1 = $toRoot.Transform([Windows.Point]::new(0, 1))
    $scale = [math]::Abs(($p1.Y - $p0.Y) * $source.CompositionTarget.TransformToDevice.M22)
    if ($scale -le 0) { return }

    $move = $face.RenderTransform
    if ($move -isnot [Windows.Media.TranslateTransform] -or $move.IsFrozen) {
        $move = [Windows.Media.TranslateTransform]::new()
        $face.RenderTransform = $move
    }
    $current = [int][math]::Round($move.Y * $scale)
    $target = if ($raised) { -[int][math]::Max(1, [math]::Round(4 * $scale)) } else { 0 }
    $distance = [math]::Abs($target - $current)
    $property = [Windows.Media.TranslateTransform]::YProperty
    $move.Y = $target / $scale
    if ($distance -eq 0) { $move.BeginAnimation($property, $null); return }

    $direction = [math]::Sign($target - $current)
    $stepMs = 120.0 / [math]::Max(1, [math]::Round(4 * $scale))
    $motion = [Windows.Media.Animation.DoubleAnimationUsingKeyFrames]::new()
    for ($i = 0; $i -le $distance; $i++) {
        $when = [Windows.Media.Animation.KeyTime]::FromTimeSpan([timespan]::FromMilliseconds($i * $stepMs))
        $y = ($current + $direction * $i) / $scale
        $frame = [Windows.Media.Animation.DiscreteDoubleKeyFrame]::new($y, $when)
        [void]$motion.KeyFrames.Add($frame)
    }
    $motion.Duration = [Windows.Duration]::new([timespan]::FromMilliseconds($distance * $stepMs))
    $motion.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
    $motion.Freeze()
    $move.BeginAnimation($property, $motion, [Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
}

function Initialize-CardShadows {
    if ($script:CardShadowsInitialized) { return }
    $script:CardShadowsInitialized = $true
    try {
        $style = $window.FindResource('GlassLift')
        $hoverStyle = $window.FindResource('CardHoverHost')
        $stack = New-Object 'System.Collections.Generic.Stack[System.Windows.DependencyObject]'
        $stack.Push($window)
        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            if ($node -is [Windows.Controls.ContentControl] -and
                [object]::ReferenceEquals($node.Style, $hoverStyle)) {
                $node.Add_MouseEnter({ param($sender, $e) Set-CardHoverLift $sender $true })
                $node.Add_MouseLeave({ param($sender, $e) Set-CardHoverLift $sender $false })
                if ($node.IsMouseOver) { Set-CardHoverLift $node $true }
            }
            if ($node -is [Windows.Controls.Border] -and
                [object]::ReferenceEquals($node.Style, $style)) {
                Set-CardShadowClip $node
                $node.Add_SizeChanged({ param($sender, $args) Set-CardShadowClip $sender })
                $caster = [Windows.Controls.Border]::new()
                $caster.CornerRadius = $node.CornerRadius
                $caster.Background = [Windows.Media.Brushes]::Black
                $caster.Effect = $window.FindResource('CardOuterShadow')
                $node.Child = $caster
            }
            $count = [Windows.Media.VisualTreeHelper]::GetChildrenCount($node)
            for ($i = 0; $i -lt $count; $i++) {
                $stack.Push([Windows.Media.VisualTreeHelper]::GetChild($node, $i))
            }
        }
    }
    catch {
        Write-HsStartupLog ('GLASS_LIFT_INIT_FALLBACK: ' + ($_ | Out-String))
    }
}

# Native HWND / DWM transitions (4.81).
# WindowChrome owns native caption hit-testing and dragging.
# No top-level scale/opacity clocks, focus animations, timer or CBT interception.
# The original FPS/telemetry/dashboard animations are NOT affected.
$script:MeterGlowInitialized = $false
$script:UiInitialized = $false

# Optional per-window Windows 11 DWM rounded-corner hint (no policy changes).
# The hint is harmlessly ignored on older or unsupported configurations.
try {
    if (-not ('ScriptXNativeDwm.WindowFrame' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ScriptXNativeDwm {
    public static class WindowFrame {
        [DllImport("dwmapi.dll", PreserveSig=true)]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute,
            ref int value, int size);
        public static void PreferRoundedCorners(IntPtr hwnd) {
            if (hwnd == IntPtr.Zero) return;
            try { int round = 2; DwmSetWindowAttribute(hwnd, 33, ref round, 4); }
            catch (DllNotFoundException) { }
            catch (EntryPointNotFoundException) { }
        }
    }
}
'@ -ErrorAction Stop
    }
    $window.Add_SourceInitialized({
        try {
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
            [ScriptXNativeDwm.WindowFrame]::PreferRoundedCorners($hwnd)
        }
        catch { Write-HsStartupLog ('DWM_CORNER_HINT_SKIPPED: ' + $_.Exception.Message) }
    })
}
catch { Write-HsStartupLog ('DWM_HELPER_SKIPPED: ' + $_.Exception.Message) }

# StateChanged controls only the dashboard's live UI workload, not window motion.
# Suspend only the on-screen meter animator while minimized; independent
# genuine FPS telemetry collection continues unchanged.
$script:LastHealthResult=$null
$script:LastHealthRequestMs=[double]::NegativeInfinity
$window.Add_StateChanged({
    if ($window.WindowState -eq [Windows.WindowState]::Minimized) {
        if ($null -ne $script:FpsFramePresenter) {
            $script:FpsFramePresenter.SetVisible($false)
        }
        if ($fpsFallbackTimer) { $fpsFallbackTimer.Stop() }
    }
    elseif ($window.WindowState -eq [Windows.WindowState]::Normal -and $script:UiInitialized) {
        if ($null -ne $script:FpsFramePresenter) {
            $script:FpsFramePresenter.SetVisible([bool](
                $ui.HomePage.Visibility -eq [Windows.Visibility]::Visible))
        }
        Restore-HealthView
        if ($fpsFallbackTimer) {
            $script:LastFpsFallbackFrame = [datetime]::UtcNow
            $fpsFallbackTimer.Start()
        }
    }
})

$window.Add_Activated({ if ($script:UiInitialized) { Restore-HealthView } })

$frameContent.Add_SizeChanged({
    $w = [math]::Max(0, $frameContent.ActualWidth)
    $h = [math]::Max(0, $frameContent.ActualHeight)
    $frameClip.Rect = [Windows.Rect]::new(0, 0, $w, $h)
})

# The OS now owns the outer window frame and native taskbar animations.
# Our WPF border and content clip remain decorative only.

$desktop = [Windows.SystemParameters]::WorkArea

$window.MinWidth = [math]::Min(
    $window.MinWidth,
    [math]::Max(640, $desktop.Width - 24)
)
$window.MinHeight = [math]::Min(
    $window.MinHeight,
    [math]::Max(440, $desktop.Height - 24)
)
$window.Width = [math]::Max(
    $window.MinWidth,
    [math]::Min($window.Width, $desktop.Width - 24)
)
$window.Height = [math]::Max(
    $window.MinHeight,
    [math]::Min($window.Height, $desktop.Height - 24)
)

# Center once before ShowDialog. Let Windows preserve native window placement
# and handle all taskbar minimize/restore transitions from here on.
$window.WindowStartupLocation = [Windows.WindowStartupLocation]::Manual
$window.Left = $desktop.Left + (($desktop.Width - $window.Width) / 2.0)
$window.Top = $desktop.Top + (($desktop.Height - $window.Height) / 2.0)

$ui = @{}
foreach ($m in [regex]::Matches($markup.OuterXml, 'x:Name="([^"]+)"')) {
    $ui[$m.Groups[1].Value] = $window.FindName($m.Groups[1].Value)
}
# C# callback lives on WPF's rendering event, not on a PowerShell UI timer.
# A failure to initialize leaves the previous, working 33ms gauge available.
$script:FpsFramePresenter = $null
if ($script:FpsNativeGaugeReady) {
    try {
        $script:FpsFramePresenter = [ScriptXVisual476.FluidFpsGauge]::new(
            $ui.FpsRingProgress, $null, $ui.FpsLive)
    }
    catch { Write-HsStartupLog ('FPS_VISUAL_INIT_FALLBACK: ' + ($_ | Out-String)) }
}

$ui.ProfileName.Text = $env:USERNAME
$ui.ProfileMachine.Text = $env:COMPUTERNAME

if ($env:USERNAME) {
    $ui.Avatar.Text = $env:USERNAME.Substring(0, 1).ToUpperInvariant()
}

# Preserve the original On Top headline font on BOTH stacked words.
$ui.DashboardHeading.FontFamily = $script:DashboardFontFamily
$ui.SystemHeading.FontFamily = $script:DashboardFontFamily
$ui.DashboardHeading.FontWeight = [Windows.FontWeights]::Normal
$ui.SystemHeading.FontWeight = [Windows.FontWeights]::Normal
$state = @{
    Pending      = $null
    Started      = [datetime]::MinValue
    Latest       = $null
    Closing      = $false
    DisplayGpuId = ''
    LastGood     = [datetime]::MinValue
    DiskKey      = ''
}

# One animated reading drives the numeric label and the fill. RangeBase
# clamps the fill to 0..100 while the temperature label keeps its full range.
# The bars are Grid children, so Canvas.Left is an unused animatable double.
$meterReadingProperty = [Windows.Controls.Canvas]::LeftProperty
$meterReadingPath = [Windows.PropertyPath]::new('(0)', [object[]]@($meterReadingProperty))
$meterSampleClock = [Diagnostics.Stopwatch]::StartNew()
$script:LastMeterSampleMs = $null
$script:MeterTravelMs = [double]$script:Config.RefreshMs
$script:LastFpsFallbackFrame = [datetime]::UtcNow
$script:FpsFallbackDeltaSeconds = 0.033

function Format-Percent($Value) {
    if ($null -eq $Value) { return 'N/A' }
    '{0:0}%' -f $Value
}

function Format-Rate($Value) {
    if ($null -eq $Value) { return '—' }
    if ($Value -ge 1MB) { return ('{0:0.0} MB/s' -f ($Value / 1MB)) }
    if ($Value -ge 1KB) { return ('{0:0} KB/s' -f ($Value / 1KB)) }
    '{0:0} B/s' -f $Value
}

function Set-Meter([string]$Name, $Value) {
    $bar = $ui[$Name + 'Bars']
    $text = $ui[$Name + 'Value']
    $number = [double]$Value
    if ($null -eq $Value -or [double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        $text.Text = 'N/A'
        $bar.BeginAnimation($meterReadingProperty, $null)
        $bar.SetValue($meterReadingProperty, 0.0)
        $bar.Opacity = 0.35
        return
    }

    $target = if ($Name -eq 'Temp') {
        [math]::Max(-20.0, [math]::Min(150.0, $number))
    } else {
        [math]::Max(0.0, [math]::Min(100.0, $number))
    }
    $labelProperty = [Windows.Controls.TextBlock]::TextProperty
    if (-not $text.GetBindingExpression($labelProperty)) {
        # First reading (also after N/A) has no preceding sample to interpolate.
        $bar.SetValue($meterReadingProperty, $target)
        $binding = [Windows.Data.Binding]::new()
        $binding.Source = $bar
        $binding.Path = $meterReadingPath
        $binding.Mode = [Windows.Data.BindingMode]::OneWay
        $binding.StringFormat = if ($Name -eq 'Temp') { '{0:0.0}°C' } else { '{0:0.0}%' }
        [void]$text.SetBinding($labelProperty, $binding)
        $fillProperty = [Windows.Controls.Primitives.RangeBase]::ValueProperty
        if (-not $bar.GetBindingExpression($fillProperty)) {
            $fill = [Windows.Data.Binding]::new()
            $fill.Source = $bar
            $fill.Path = $meterReadingPath
            $fill.Mode = [Windows.Data.BindingMode]::OneWay
            [void]$bar.SetBinding($fillProperty, $fill)
        }
        $bar.Opacity = 1
        return
    }
    if ($bar.GetAnimationBaseValue($meterReadingProperty) -eq $target) { return }

    $from = [double]$bar.GetValue($meterReadingProperty)
    $bar.SetValue($meterReadingProperty, $target)
    if (-not $bar.IsVisible -or $window.WindowState -eq [Windows.WindowState]::Minimized -or $from -eq $target) {
        $bar.BeginAnimation($meterReadingProperty, $null)
        return
    }
    $duration = [Windows.Duration]::new([timespan]::FromMilliseconds($script:MeterTravelMs))
    $motion = [Windows.Media.Animation.DoubleAnimation]::new($from, $target, $duration)
    $motion.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
    $motion.Freeze()
    $bar.BeginAnimation($meterReadingProperty, $motion, [Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
}

function Load-Badge($Value) {
    if ($null -eq $Value) { return 'N/A' }
    if ($Value -ge 80) { return 'HIGH' }
    if ($Value -ge 40) { return 'MID' }
    'LOW'
}

function Select-DisplayGpu($Data) {
    $physical = @($Data.Gpus | Where-Object { $_.Kind -eq 'adapter' })
    if (-not $physical.Count) { return $null }

    $gpu = $physical |
        Where-Object { $_.Id -eq $state.DisplayGpuId } |
        Select-Object -First 1

    if (-not $gpu) {
        $gpu = $physical |
            Where-Object { $_.Id -eq $script:Config.SelectedGpu } |
            Select-Object -First 1
    }

    if (-not $gpu) {
        $gpu = $physical |
            Where-Object { $_.Source -eq 'NVIDIA driver' } |
            Sort-Object Load -Descending |
            Select-Object -First 1
    }

    if (-not $gpu) {
        $gpu = $physical |
            Where-Object { $null -ne $_.Load -or $null -ne $_.Temp } |
            Sort-Object Load -Descending |
            Select-Object -First 1
    }

    if (-not $gpu) { $gpu = $physical[0] }
    $state.DisplayGpuId = $gpu.Id

    if ($physical.Count -eq 1 -and $null -eq $gpu.Load) {
        $engine = $Data.Gpus |
            Where-Object { $_.Kind -eq 'aggregate' } |
            Select-Object -First 1

        if ($engine -and $null -ne $engine.Load) {
            $gpu = $gpu.PSObject.Copy()
            $gpu.Load = $engine.Load
            $gpu.Source = $gpu.Source + ' / Windows engine load (single adapter)'
        }
    }

    return $gpu
}

function Get-CompactModelLabel {
    param([string]$Name, [string]$Kind = 'Device')
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'NOT DETECTED' }
    $clean = ($Name -replace '(?i)\(R\)|\(TM\)|[®™]', '' -replace '\s+', ' ').Trim()
    if ($Kind -eq 'Cpu') {
        $part = [regex]::Match($clean, '(?i)\b(?:i[3579]-\d{4,5}[A-Z]*|Core Ultra\s+\d{3}[A-Z]*|Ryzen\s+\d+\s+\d+[A-Z0-9]*)\b')
        if ($part.Success) {
            if ($clean -match '(?i)Intel') { return ('Intel ' + $part.Value) }
            if ($clean -match '(?i)AMD') { return ('AMD ' + $part.Value) }
            return $part.Value
        }
    }
    if ($Kind -eq 'Gpu') {
        $part = [regex]::Match($clean, '(?i)\b(?:RTX|GTX|RX|ARC)\s*\d{3,5}(?:\s*(?:Ti|SUPER|XTX|XT))?\b')
        if ($part.Success) {
            if ($clean -match '(?i)NVIDIA') { return ('NVIDIA ' + $part.Value) }
            if ($clean -match '(?i)AMD|Radeon') { return ('AMD ' + $part.Value) }
            if ($clean -match '(?i)Intel') { return ('Intel ' + $part.Value) }
            return $part.Value
        }
    }
    return $clean
}

function Show-Gpu($Gpu) {
    $ui.GpuName.Text = if ($Gpu) { Get-CompactModelLabel -Name $Gpu.Name -Kind 'Gpu' } else { 'GPU NOT DETECTED' }
    $ui.GpuBadge.Text = Load-Badge $Gpu.Load

    Set-Meter 'Gpu' $Gpu.Load

    $temp = $null
    if (
        $Gpu -and $null -ne $Gpu.Temp -and
        $Gpu.Temp -ge -20 -and $Gpu.Temp -le 150
    ) {
        $temp = $Gpu.Temp
    }

    $ui.TempBadge.Text = if ($null -ne $temp) { 'GPU' } else { 'N/A' }

    $ui.TempDetail.Text = if ($Gpu) {
        $gpuModel = Get-CompactModelLabel -Name $Gpu.Name -Kind 'Gpu'
        $gpuModel -replace '^NVIDIA ', '' -replace '^AMD ', ''
    }
    else {
        'GPU SENSOR UNAVAILABLE'
    }


    Set-Meter 'Temp' $temp
}

function Show-Disks($Disks) {
    $key = $Disks | ConvertTo-Json -Compress
    if ($state.DiskKey -eq $key) { return }

    $state.DiskKey = $key
    $ui.Storage.Children.Clear()
    $all = @($Disks)

    foreach ($disk in $all | Select-Object -First 3) {
        $box = New-Object Windows.Controls.Border
        $box.CornerRadius = [Windows.CornerRadius]::new(11)
        $box.Background = $window.FindResource('InsetGlass')
        $box.BorderThickness = [Windows.Thickness]::new(0)
        $box.Padding = [Windows.Thickness]::new(12,7,12,7)
        $box.Margin = [Windows.Thickness]::new(0,0,0,8)
        $inner = New-Object Windows.Controls.StackPanel

        $name = New-Object Windows.Controls.TextBlock
        $name.FontFamily = $script:UiFontFamily
        $name.FontSize = 11.5
        $name.FontWeight = [Windows.FontWeights]::Bold
        $name.Foreground = $window.FindResource('StorageTileText')
        $name.TextWrapping = 'NoWrap'
        $name.TextTrimming = 'CharacterEllipsis'
        $name.Text = '{0}  {1}  /  {2:0}% used' -f `
            $disk.Name, $disk.Label, $disk.UsedPercent

        $bar = New-Object Windows.Controls.ProgressBar
        $bar.Value = [math]::Max(0, [math]::Min(100, [double]$disk.UsedPercent))
        $bar.Height = 6
        $bar.Margin = [Windows.Thickness]::new(0,8,0,0)
        # The two visible drive bars glow without applying effects to their labels.
        $bar.Style = if ($disk.UsedPercent -ge 90) {
            $window.FindResource('DiskWarnGlowMeter')
        } else {
            $window.FindResource('DiskGlowMeter')
        }

        [void]$inner.Children.Add($name)
        [void]$inner.Children.Add($bar)
        $box.Child = $inner
        [void]$ui.Storage.Children.Add($box)
    }

    if ($all.Count -gt 3) {
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = '+ ' + ($all.Count - 3) + ' additional volumes'
        $t.FontSize = 9
        [void]$ui.Storage.Children.Add($t)
    }

    if (-not $all.Count) {
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = 'Volume data unavailable'
        $t.FontSize = 11
        [void]$ui.Storage.Children.Add($t)
    }
}

function Clear-HealthRing {
    $arc = $ui.HealthArc
    $arc.BeginAnimation($meterReadingProperty, $null)
    $arc.BeginAnimation([Windows.Shapes.Shape]::StrokeDashOffsetProperty, $null)
    $arc.SetValue($meterReadingProperty, 0.0)
    $ui.HealthValue.Text = '—'
}

function Set-HealthRing([double]$score, [switch]$Immediate) {
    $arc = $ui.HealthArc
    $text = $ui.HealthValue
    $textProperty = [Windows.Controls.TextBlock]::TextProperty
    $offsetProperty = [Windows.Shapes.Shape]::StrokeDashOffsetProperty
    $length = $arc.StrokeDashArray[0]
    $offset = $length * (1.0 - $score / 100.0)
    $first = $null -eq $text.GetBindingExpression($textProperty)
    if (-not $first -and (-not $Immediate -or $arc.GetValue($meterReadingProperty) -eq $score) -and $arc.GetAnimationBaseValue($meterReadingProperty) -eq $score) { return }

    # Both timelines use the same start fraction, duration and WPF timing tick.
    $fromScore = [double]$arc.GetValue($meterReadingProperty)
    $fromOffset = $arc.StrokeDashOffset
    $arc.SetValue($meterReadingProperty, $score)
    $arc.StrokeDashOffset = $offset
    if ($first) {
        $binding = [Windows.Data.Binding]::new()
        $binding.Source = $arc
        $binding.Path = $meterReadingPath
        $binding.Mode = [Windows.Data.BindingMode]::OneWay
        $binding.StringFormat = '{0:0}%'
        [void]$text.SetBinding($textProperty, $binding)
        return
    }
    if ($Immediate -or -not $text.IsVisible -or $window.WindowState -eq [Windows.WindowState]::Minimized) {
        $arc.BeginAnimation($meterReadingProperty, $null)
        $arc.BeginAnimation($offsetProperty, $null)
        return
    }
    $duration = [Windows.Duration]::new([timespan]::FromMilliseconds($script:MeterTravelMs))
    $number = [Windows.Media.Animation.DoubleAnimation]::new($fromScore, $score, $duration)
    $sweep = [Windows.Media.Animation.DoubleAnimation]::new($fromOffset, $offset, $duration)
    foreach ($motion in @($number, $sweep)) {
        $motion.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop
        $motion.Freeze()
    }
    $arc.BeginAnimation($meterReadingProperty, $number)
    $arc.BeginAnimation($offsetProperty, $sweep)
}

function Reset-SystemHealth([string]$reason) {
    Clear-HealthRing
    $ui.HealthState.Text = $reason
    $ui.HealthState.Foreground = '#9FB4C5'
    $ui.HealthOne.Text = 'Temperature —'
    $ui.HealthTwo.Text = 'Memory —'
    $ui.HealthThree.Text = 'Disk / HW —'
    foreach ($row in @($ui.HealthOne, $ui.HealthTwo, $ui.HealthThree)) {
        $row.ToolTip = $null
    }
    $ui.HealthState.ToolTip = $null
}

# Health V2 projects the worker's decision into the existing card.
function Update-SystemHealth($result, [switch]$Immediate) {
    if (-not $result) { Reset-SystemHealth 'INSUFFICIENT DATA'; return }
    $age=([datetime]::UtcNow-$result.Timestamp).TotalSeconds
    if ($age -lt 0 -or $age -gt 15) {Reset-SystemHealth 'STALE DATA'; return}
    $c=$result.Categories
    $lines=@("Estimated operating health · $($result.Timestamp.ToLocalTime().ToString('HH:mm:ss'))",
        "Scored domains: $($result.DataCoverage) · complete: $($result.CompleteDomains)/4 · confidence: $($result.Confidence)")
    foreach ($domain in $c.Values) {
        $sampleTime=if ($domain.Timestamp -and $domain.Timestamp -gt [datetime]::MinValue) {
            $domain.Timestamp.ToLocalTime().ToString('HH:mm:ss')
        } else { 'no sample' }
        $lines += "$($domain.Name) · $($domain.Status) · $sampleTime · $($domain.Reason)"
    }
    $ui.HealthState.ToolTip=$lines -join [environment]::NewLine
    $ui.HealthOne.ToolTip = @($c.Thermal.Reason,$c.Thermal.Observations) -join [environment]::NewLine
    $ui.HealthTwo.ToolTip = $c.Memory.Reason
    $ui.HealthThree.ToolTip = "$($c.Storage.Reason) / $($c.WHEA.Reason)"
    $visibleTemps=@()
    if ($c.Thermal.Status -in @('Available','Warning','Critical')) {
        foreach ($type in @('CPU Package','GPU Core')) {
            $peak=$null
            foreach ($ch in $c.Thermal.Details) {
                if ($ch.Kind -eq $type -and $null -ne $ch.Value -and $ch.Value -ge -30 -and $ch.Value -le 160 -and ($null -eq $peak -or $ch.Value -gt $peak)) {$peak=$ch.Value}
            }
            if ($null -eq $peak) {$visibleTemps+=('{0} —' -f $type.Substring(0,3))}
            else {$visibleTemps+=('{0} {1:0}°' -f $type.Substring(0,3),$peak)}
        }
    }
    $ui.HealthOne.Text = if ($visibleTemps.Count) {$visibleTemps -join ' / '} else {"Temp · $($c.Thermal.Status)"}
    $ui.HealthTwo.Text = if ($c.Memory.Pressure -eq 'Normal' -and $null -ne $c.Memory.Details.Commit) {
        'Commit {0:0}%' -f $c.Memory.Details.Commit
    } elseif ($c.Memory.Pressure) {"RAM · $($c.Memory.Pressure)"} else {"RAM · $($c.Memory.Status)"}
    $short=@{Available='OK';Unavailable='?';Stale='stale';Critical='FAIL';Warning='warn'}
    $diskLabel=if ($c.Storage.Status -eq 'Available' -and -not $c.Storage.Complete) {'partial'} else {$short[$c.Storage.Status]}
    $hwLabel=$short[$c.WHEA.Status]
    if ($c.WHEA.Status -eq 'Available') {
        foreach ($evt in $c.WHEA.Details) {if ($evt.Class -eq 'Corrected') {$hwLabel='corr.';break}}
    }
    $ui.HealthThree.Text = "Disk $diskLabel · HW $hwLabel"
    $label=$result.Status
    if ($null -ne $result.Score -and $result.Confidence -ne 'High') {$label+=' (EST.)'}
    $ui.HealthState.Text=$label
    $color=switch ($result.Status) {
        ATTENTION {'#F58282'} CHECK {'#F5BD68'} 'INSUFFICIENT DATA' {'#9FB4C5'} default {'#39D6A4'}
    }
    $ui.HealthState.Foreground=$color
    $ui.HealthArc.Stroke=$ui.HealthState.Foreground
    if ($null -eq $result.Score) {Clear-HealthRing; $ui.HealthValue.Text='N/A'}
    else {Set-HealthRing $result.Score -Immediate:($Immediate -or $result.Critical)}
}

function Show-NetworkReading($n) {
    $ui.NetHeading.ToolTip = if ($n.Connected) { $n.Name } else { 'No current adapter reading' }
    $ui.NetPing.ToolTip = if ($n.PingTarget) { "ICMP round trip to $($n.PingTarget) via $($n.Name)" } else { 'No ping destination available' }
    $ui.NetPing.Text = if ($null -ne $n.Ping) {
        if ($n.Ping -eq 0) { '<1 ms' } else { '{0:0} ms' -f $n.Ping }
    } elseif ($null -eq $n) { '—' } elseif (-not $n.Connected) { 'Offline' } elseif ($n.PingTarget) { 'No reply' } else { 'N/A' }
    $ui.NetDown.Text = Format-Rate $n.DownBps
    $ui.NetUp.Text = Format-Rate $n.UpBps
    $ui.NetJitter.Text = if ($null -ne $n.Jitter) { '{0:0.0} ms' -f $n.Jitter } else { '—' }
}

# SHOW SPEC ONLY: compact, model-preserving identifiers for the five-field rail.
# Never alter the raw inventory or the CPU/GPU names used by other cards.
function Add-ShowSpecOption($Options, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $label = (($Value -replace '\s+', ' ').Trim() -replace '^[\s,/-]+|[\s,/-]+$', '').Trim()
    if ($label -and -not $Options.Contains($label)) { [void]$Options.Add($label) }
}

function Get-ShowSpecOptions([string]$Raw, [string]$Kind) {
    $options = New-Object 'System.Collections.Generic.List[string]'
    if ([string]::IsNullOrWhiteSpace($Raw)) { return @('Unavailable') }
    $name = ($Raw -replace '(?i)\((?:R|TM)\)|[®™]', '' -replace '\s+', ' ').Trim()
    switch ($Kind) {
        'Cpu' {
            $found = [regex]::Match($name, '(?i)\b(?:Core\s+)?Ultra\s+[3579]\s+\d{2,4}[A-Z0-9]*\b')
            if ($found.Success) {
                Add-ShowSpecOption $options $found.Value
                Add-ShowSpecOption $options ($found.Value -replace '(?i)^Core\s+', '')
            }
            $found = [regex]::Match($name, '(?i)\bCore\s+[3579]\s+\d{2,5}[A-Z0-9]*\b')
            if ($found.Success) { Add-ShowSpecOption $options $found.Value }
            $found = [regex]::Match($name, '(?i)\bi[3579]-\d{3,6}[A-Z0-9]*\b')
            if ($found.Success) {
                Add-ShowSpecOption $options ('Core ' + $found.Value)
                Add-ShowSpecOption $options $found.Value
            }
            $found = [regex]::Match($name, '(?i)\bRyzen\s+AI\s+(?:Max\s+)?(?:PRO\s+)?\d+\s+(?:HX\s+)?\d{2,4}[A-Z0-9]*\b|\bRyzen\s+(?:Threadripper\s+)?(?:PRO\s+)?[3579]\s+\d{3,5}[A-Z0-9]*\b|\bRyzen\s+(?:Threadripper\s+)?(?:PRO\s+)?\d{3,5}[A-Z0-9]*\b|\bThreadripper\s+(?:PRO\s+)?\d{3,5}[A-Z0-9]*\b')
            if ($found.Success) { Add-ShowSpecOption $options $found.Value }
            $found = [regex]::Match($name, '(?i)\b(?:Xeon\s+(?:(?:Gold|Silver|Bronze|Platinum)\s+)?[A-Z]?[-\s]?\d{3,5}[A-Z]*|EPYC\s+\d{3,5}[A-Z]*|Athlon\s+\d{3,5}[A-Z]*)\b')
            if ($found.Success) { Add-ShowSpecOption $options $found.Value }
            # For unfamiliar CPUs, retain actual identifier rather than guessing a generation.
            $fallback = $name -replace '(?i)^(?:Intel|AMD)\s+', '' -replace '(?i)\b(?:Processor|CPU|with Radeon Graphics)\b', '' -replace '(?i)\s*@\s*[\d.]+\s*GHz.*$', ''
            Add-ShowSpecOption $options $fallback
        }
        'Gpu' {
            $found = [regex]::Match($name, '(?i)\b(?:RTX|GTX|MX)\s*\d{3,5}\s*(?:Ti|SUPER)?\b|\bRTX\s+[A-Z]\d{3,5}\b|\bRX\s*\d{3,5}\s*(?:XT|XTX|GRE)?\b|\bArc\s+(?:Pro\s+)?[A-Z]\d{2,4}\b|\b(?:UHD|HD)\s+(?:Graphics\s+)?\d{2,4}\b|\bIris\s+(?:Xe|Plus)\b|\bRadeon\s+(?:Pro\s+)?[A-Z]?\d{3,5}[A-Z]*\b|\bQuadro\s+[A-Z]?\d{3,5}\b')
            if ($found.Success) {
                $gpuModel = $found.Value -replace '(?i)\s+Graphics\s+', ' '
                Add-ShowSpecOption $options $gpuModel
            }
            $fallback = $name -replace '(?i)^(?:NVIDIA\s+(?:GeForce\s+)?|AMD\s+Radeon\s+|Intel\s+)', '' -replace '(?i)\bGraphics\b', '' -replace '(?i)\b(?:Corporation|Series)\b', ''
            Add-ShowSpecOption $options $fallback
            Add-ShowSpecOption $options $name
        }
        'Board' {
            $board = $name
            $brand = ''
            if ($board -match '(?i)^Micro-Star\s+International(?:\s+Co\.,?\s*Ltd\.?)?\s*') {
                $brand = 'MSI'; $board = $board -replace '(?i)^Micro-Star\s+International(?:\s+Co\.,?\s*Ltd\.?)?\s*', ''
            } elseif ($board -match '(?i)^(?:ASUSTeK\s+COMPUTER(?:\s+INC\.?)?|ASUS)\s*') {
                $brand = 'ASUS'; $board = $board -replace '(?i)^(?:ASUSTeK\s+COMPUTER(?:\s+INC\.?)?|ASUS)\s*', ''
            } elseif ($board -match '(?i)^(?:GIGABYTE\s+TECHNOLOGY(?:\s+CO\.,?\s*LTD\.?)?|GIGABYTE)\s*') {
                $brand = 'Gigabyte'; $board = $board -replace '(?i)^(?:GIGABYTE\s+TECHNOLOGY(?:\s+CO\.,?\s*LTD\.?)?|GIGABYTE)\s*', ''
            } elseif ($board -match '(?i)^(?:ASRock|Dell(?:\s+Inc\.?)?|Lenovo|Hewlett-Packard|HP|Acer|BIOSTAR|Supermicro|Framework)\s*') {
                $brand = $Matches[0].Trim()
                if ($brand -match '(?i)Hewlett-Packard') { $brand = 'HP' }
                if ($brand -match '(?i)^Dell') { $brand = 'Dell' }
                $board = $board -replace '(?i)^(?:ASRock|Dell(?:\s+Inc\.?)?|Lenovo|Hewlett-Packard|HP|Acer|BIOSTAR|Supermicro|Framework)\s*', ''
            }
            $board = ($board -replace '(?i)\b(?:Motherboard|Mainboard)\b', '' -replace '\s+', ' ').Trim()
            if ($board -and $board -notmatch '(?i)^(?:to be filled by o\.?e\.?m\.?|default string|system product name|not available|unknown)$') {
                Add-ShowSpecOption $options ((@($brand, $board) | Where-Object { $_ }) -join ' ')
                $condensed = ($board -replace '(?i)\b(?:GAMING|PRO|SERIES|REV(?:ISION)?\.?\s*\d+(?:\.\d+)?)\b', '' -replace '\s+', ' ').Trim()
                Add-ShowSpecOption $options ((@($brand, $condensed) | Where-Object { $_ }) -join ' ')
                Add-ShowSpecOption $options $board
                Add-ShowSpecOption $options $condensed
                $id = [regex]::Match($board, '(?i)\b(?:[A-Z]{1,6}\d{2,5}|\d[A-Z]\d{2,5})[A-Z0-9-]*\b')
                if ($id.Success) {
                    $tail = $board.Substring($id.Index)
                    Add-ShowSpecOption $options $tail
                    Add-ShowSpecOption $options $id.Value
                }
            } else {
                Add-ShowSpecOption $options $brand
                Add-ShowSpecOption $options 'Board unavailable'
            }
        }
        'OS' {
            $caption = $name -replace '(?i)^Microsoft\s+', ''
            $server = [regex]::Match($caption, '(?i)\bWindows\s+Server\s+(?:20\d{2}|20\d{2}\s+R2)\b')
            if ($server.Success) {
                $edition = [regex]::Match($caption, '(?i)\b(?:Datacenter|Standard|Essentials)\b')
                $version = $server.Value -replace '(?i)^Windows\s+', ''
                if ($edition.Success) { Add-ShowSpecOption $options ($version + ' ' + $edition.Value) }
                Add-ShowSpecOption $options $version
            } else {
                $v = [regex]::Match($caption, '(?i)\bWindows\s+(?:11|10|8\.1|8|7)\b')
                if ($v.Success) {
                    $short = $v.Value -replace '(?i)^Windows\s+', 'Win '
                    $edition = [regex]::Match($caption, '(?i)\b(?:Home|Pro|Enterprise|Education|Professional|Ultimate|Starter)\b')
                    if ($edition.Success) {
                        $type = $edition.Value
                        if ($caption -match '(?i)Home\s+Single\s+Language') { $type = 'Home SL' }
                        if ($caption -match '(?i)Pro\s+for\s+Workstations') { $type = 'Pro WS' }
                        Add-ShowSpecOption $options ($short + ' ' + $type)
                    }
                    Add-ShowSpecOption $options $short
                }
            }
            Add-ShowSpecOption $options $caption
        }
        default { Add-ShowSpecOption $options $name }
    }
    return $options.ToArray()
}

function Set-ShowSpecLabel([Windows.Controls.TextBlock]$Target, [string[]]$Candidates) {
    if (-not $Candidates -or $Candidates.Count -eq 0) { $Target.Text = 'Unavailable'; return }
    # Each field has a fixed-width column inside the existing 824-DIP Home Viewbox.
    # Measure at the actual WPF font instead of estimating characters or clipping model IDs.
    $limit = 140.0
    if ($Target.Parent -is [Windows.FrameworkElement] -and $Target.Parent.ActualWidth -gt 60) {
        $limit = [math]::Max(65.0, [double]$Target.Parent.ActualWidth - 2.0)
    }
    $probe = [Windows.Controls.TextBlock]::new()
    $probe.FontFamily = $Target.FontFamily
    $probe.FontWeight = $Target.FontWeight
    $probe.FontSize = $Target.FontSize
    $probe.FontStyle = $Target.FontStyle
    $probe.FontStretch = $Target.FontStretch
    $probe.TextWrapping = [Windows.TextWrapping]::NoWrap
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $probe.Text = $candidate
        $probe.Measure([Windows.Size]::new(4096.0, 80.0))
        if ($probe.DesiredSize.Width -le $limit) {
            $Target.TextWrapping = [Windows.TextWrapping]::NoWrap
            $Target.MaxHeight = [double]::PositiveInfinity
            $Target.Text = $candidate
            return
        }
    }
    # Unusual OEM identifiers may exceed one line even after stripping filler words.
    # Preserve the model rather than truncating it to an unreadable '...'.
    $Target.TextWrapping = [Windows.TextWrapping]::Wrap
    $Target.MaxHeight = 29.0
    $Target.Text = $Candidates[$Candidates.Count - 1]
}

function Update-ShowSpec($Data, $DisplayGpu) {
    $inventory = $Data.Inventory
    $rawCpu = [string]$inventory.Cpu
    $allGpu = @($inventory.GpuNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $gpuName = if ($DisplayGpu -and $DisplayGpu.Name -and $DisplayGpu.Kind -eq 'adapter') { [string]$DisplayGpu.Name } elseif ($allGpu.Count) { [string]$allGpu[0] } else { '' }
    $gpuExtra = [math]::Max(0, $allGpu.Count - 1)
    $rawBoard = [string]$inventory.Board
    $osName = [string]$Data.OS
    $ramGb = [double]$inventory.MemoryGB
    $ramSpeed = [double]$inventory.MemorySpeed
    $key = (@($rawCpu, ($allGpu -join ' / '), $gpuName, $rawBoard, $osName, $ramGb, $ramSpeed) -join [char]31)
    if ($script:LastShowSpecKey -ceq $key) { return }
    $script:LastShowSpecKey = $key

    $cpuParts = @($rawCpu -split '\s+/\s+' | Where-Object { $_ })
    $cpuOptions = @(Get-ShowSpecOptions $(if ($cpuParts.Count) { $cpuParts[0] } else { '' }) 'Cpu')
    if ($cpuParts.Count -gt 1) {
        $cpuOptions = @($cpuOptions | ForEach-Object { "$_ +$($cpuParts.Count - 1)" }) + $cpuOptions
    }
    Set-ShowSpecLabel $ui.SpecCpu $cpuOptions

    $gpuOptions = @(Get-ShowSpecOptions $gpuName 'Gpu')
    if ($gpuExtra -gt 0) { $gpuOptions = @($gpuOptions | ForEach-Object { "$_ +$gpuExtra" }) + $gpuOptions }
    Set-ShowSpecLabel $ui.SpecGpu $gpuOptions

    $memoryOptions = @('Unavailable')
    if ($ramGb -gt 0) {
        $memoryOptions = @()
        if ($ramSpeed -ge 200 -and $ramSpeed -le 20000) {
            $memoryOptions += ('{0:0.#} GB · {1:0} MT/s' -f $ramGb, $ramSpeed)
        }
        $memoryOptions += ('{0:0.#} GB RAM' -f $ramGb)
        $memoryOptions += ('{0:0.#} GB' -f $ramGb)
    }
    Set-ShowSpecLabel $ui.SpecRam $memoryOptions

    $boardParts = @($rawBoard -split '\s+/\s+' | Where-Object { $_ })
    $boardOptions = @(Get-ShowSpecOptions $(if ($boardParts.Count) { $boardParts[0] } else { '' }) 'Board')
    Set-ShowSpecLabel $ui.SpecBoard $boardOptions
    Set-ShowSpecLabel $ui.SpecOS @(Get-ShowSpecOptions $osName 'OS')
}

function Show-Reading($d) {
    $nowMs = $meterSampleClock.Elapsed.TotalMilliseconds
    $period = [double]$script:Config.RefreshMs
    # Cover the observed interval plus one dispatcher tick of scheduling slack.
    # Bound the estimate after sleep or a stalled provider.
    $interval = if ($null -eq $script:LastMeterSampleMs) { $period } else {
        [math]::Max($period, [math]::Min(2 * $period, $nowMs - $script:LastMeterSampleMs))
    }
    $script:MeterTravelMs = $interval + $timer.Interval.TotalMilliseconds
    $script:LastMeterSampleMs = $nowMs
    $state.Latest = $d
    $state.LastGood = Get-Date

    $ui.Connection.Text = if ($d.OS -and $null -ne $d.Cpu) {
        '● LIVE SYSTEM OVERVIEW'
    }
    else {
        '● SOME SOURCES UNAVAILABLE'
    }


    $ui.CpuBadge.Text = Load-Badge $d.Cpu
    $ui.CpuDetail.Text = Get-CompactModelLabel -Name $d.Inventory.Cpu -Kind 'Cpu'
    Set-Meter 'Cpu' $d.Cpu

    $ui.RamBadge.Text = Load-Badge $d.MemoryPercent
    $ui.RamDetail.Text = if ($d.Inventory.MemoryGB -gt 0) {
        '{0:0.0} GB INSTALLED' -f $d.Inventory.MemoryGB
    }
    elseif ($d.MemoryTotal -gt 0) {
        '{0:0.0} GB AVAILABLE' -f ($d.MemoryTotal / 1GB)
    }
    else {
        'RAM NOT DETECTED'
    }

    Set-Meter 'Ram' $d.MemoryPercent

    $displayGpu = Select-DisplayGpu $d
    Show-Gpu $displayGpu

    if ($null -ne $d.UptimeSeconds) {
        $up = [timespan]::FromSeconds($d.UptimeSeconds)
        $ui.Uptime.Text = '{0}d {1:00}h {2:00}m' -f $up.Days, $up.Hours, $up.Minutes
    }
    else {
        $ui.Uptime.Text = 'N/A'
    }

    if ($null -ne $d.HealthV2) {
        $script:LastHealthResult=$d.HealthV2
        if ($ui.HomePage.IsVisible -and $window.WindowState -ne [Windows.WindowState]::Minimized) {
            Update-SystemHealth $d.HealthV2
        }
    }

    Show-Disks $d.Disks

    Show-NetworkReading $d.Network

    Update-ShowSpec $d $displayGpu

    $ui.ProfileStatus.Text = if ($complete) { '● CONNECTED' } else { '● PARTIAL DATA' }
    $ui.ProviderStatus.Text = ''

}

# Background telemetry worker.
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = 'MTA'
$runspace.Open()

$worker = [powershell]::Create()
$worker.Runspace = $runspace

$providerSource = @'
function Get-CimSafe {
    param(
        [string]$Class,
        [string]$Filter,
        [string]$Namespace = 'root/cimv2'
    )

    try {
        $parameters = @{
            ClassName           = $Class
            Namespace           = $Namespace
            OperationTimeoutSec = 2
            ErrorAction         = 'Stop'
        }
        if ($Filter) { $parameters.Filter = $Filter }
        @(Get-CimInstance @parameters)
    }
    catch {
        @()
    }
}

function Convert-Number($Value) {
    $parsed = 0.0

    if (
        [double]::TryParse(
            [string]$Value,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$parsed
        ) -and
        -not [double]::IsNaN($parsed) -and
        -not [double]::IsInfinity($parsed)
    ) {
        return $parsed
    }

    return $null
}

function Normalize-GpuName([string]$Name) {
    ($Name.ToLowerInvariant() -replace '\(r\)|\(tm\)|nvidia|advanced micro devices|amd|intel|corporation|graphics|[^a-z0-9]', '')
}

function Get-Inventory {
    $cpu = @(Get-CimSafe Win32_Processor)
    $ram = @(Get-CimSafe Win32_PhysicalMemory)
    $board = @(Get-CimSafe Win32_BaseBoard)
    $gpu = @(Get-CimSafe Win32_VideoController)

    $adapterIndex = 0
    $adapters = @(
        foreach ($device in $gpu | Where-Object Name) {
            [pscustomobject]@{
                Id = ('wmi:{0}:{1}:{2}' -f $device.DeviceID, $device.PNPDeviceID, $adapterIndex)
                Name = $device.Name
            }
            $adapterIndex++
        }
    )

    [pscustomobject]@{
        CpuCount = $cpu.Count
        Cpu = (@($cpu | Where-Object Name | ForEach-Object { $_.Name.Trim() }) -join ' / ')
        Cores = ($cpu | Measure-Object NumberOfCores -Sum).Sum
        Threads = ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
        Board = (@($board | Where-Object Product | ForEach-Object {
            "$($_.Manufacturer) $($_.Product)"
        }) -join ' / ')
        MemoryGB = ($ram | Measure-Object Capacity -Sum).Sum / 1GB
        MemorySpeed = ($ram | Where-Object ConfiguredClockSpeed |
            Measure-Object ConfiguredClockSpeed -Minimum).Minimum
        GpuNames = @($gpu | Where-Object Name | ForEach-Object { $_.Name })
        Adapters = $adapters
        Machine = $env:COMPUTERNAME
        User = $env:USERNAME
    }
}

function Invoke-NvidiaQuery {
    param([string]$Executable)

    if (-not $Executable) { return @() }

    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $Executable
    $process.StartInfo.Arguments = '--query-gpu=uuid,name,utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true

    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()

        if (-not $process.WaitForExit(1800)) {
            $process.Kill()
            return @()
        }

        if ($process.ExitCode -ne 0) { return @() }

        $rows = @($stdout.Result | ConvertFrom-Csv -Header Id,Name,Load,Temp,Used,Total)

        foreach ($row in $rows) {
            if (-not $row.Id -or -not $row.Name) { continue }

            [pscustomobject]@{
                Id = 'nv:' + $row.Id.Trim()
                Name = $row.Name.Trim()
                Load = (Convert-Number $row.Load)
                Temp = (Convert-Number $row.Temp)
                UsedMB = (Convert-Number $row.Used)
                TotalMB = (Convert-Number $row.Total)
                Source = 'NVIDIA driver'
                Kind = 'adapter'
            }
        }
    }
    catch {
        @()
    }
    finally {
        $process.Dispose()
    }
}

function Get-SensorData([bool]$IncludeHealth) {
    $sensors = @(Get-CimSafe Sensor '' 'root/LibreHardwareMonitor')
    $hardware = @()

    if ($sensors.Count) {
        $hardware = @(Get-CimSafe Hardware '' 'root/LibreHardwareMonitor')
    }

    $candidates = @(
        $sensors |
        Where-Object {
            $_.SensorType -eq 'Temperature' -and
            $_.Identifier -match '^/(intelcpu|amdcpu)/' -and
            $_.Name -match '(?i)package|tctl|tdie|cpu die'
        } |
        Sort-Object @{
            Expression = {
                if ($_.Name -match '(?i)package') { 0 }
                elseif ($_.Name -match '(?i)tctl') { 1 }
                else { 2 }
            }
        }
    )

    $cpuTemperature = $null
    $cpuSensor = 'CPU package sensor unavailable'

    if ($candidates.Count) {
        $v = Convert-Number $candidates[0].Value
        if ($null -ne $v -and $v -ge -20 -and $v -le 150) {
            $cpuTemperature = $v
            $cpuSensor = $candidates[0].Name
        }
    }

    $gpus = @(
        foreach ($hw in $hardware | Where-Object { $_.HardwareType -match '(?i)^Gpu' }) {
            $own = @($sensors | Where-Object { $_.Parent -eq $hw.Identifier })

            $load = $own | Where-Object {
                $_.SensorType -eq 'Load' -and $_.Name -match '(?i)GPU Core'
            } | Select-Object -First 1

            $temp = $own | Where-Object {
                $_.SensorType -eq 'Temperature' -and $_.Name -match '(?i)GPU Core'
            } | Select-Object -First 1

            $used = $own | Where-Object {
                $_.SensorType -eq 'SmallData' -and $_.Name -match '(?i)GPU Memory Used'
            } | Select-Object -First 1

            $total = $own | Where-Object {
                $_.SensorType -eq 'SmallData' -and $_.Name -match '(?i)GPU Memory Total'
            } | Select-Object -First 1

            [pscustomobject]@{
                Id = 'lhm:' + $hw.Identifier
                Name = $hw.Name
                Load = (Convert-Number $load.Value)
                Temp = (Convert-Number $temp.Value)
                UsedMB = (Convert-Number $used.Value)
                TotalMB = (Convert-Number $total.Value)
                Source = 'LibreHardwareMonitor'
                Kind = 'adapter'
            }
        }
    )

    $healthSensors=@()
    if ($IncludeHealth) {
        $sampleAt=[datetime]::UtcNow
        $owners=@{}
        foreach ($hw in $hardware) {if ($hw.Identifier) {$owners[[string]$hw.Identifier]=$hw}}
        foreach ($channel in $sensors) {
            $parent=[string]$channel.Parent
            if (-not $parent -or -not $owners.ContainsKey($parent) -or $channel.SensorType -ne 'Temperature' -or
                -not ([string]$channel.Identifier).StartsWith($parent+'/')) {continue}
            $hw=$owners[$parent]
            $kind=if ($hw.HardwareType -match '^(Cpu)$' -and $parent -match '^/(intelcpu|amdcpu)/') {
                if ($channel.Name -match '(?i)distance to (tj\.?\s*max|tjmax)') {'CPU Margin'}
                elseif ($channel.Name -match '(?i)package|tctl|tdie|cpu die') {'CPU Package'}
            } elseif ($hw.HardwareType -match '^Gpu(Nvidia|Amd|Intel)$') {
                if ($channel.Name -match '(?i)^GPU (hot\s*spot|junction)( temperature)?$') {'GPU Hotspot'}
                elseif ($channel.Name -match '(?i)^GPU Core$') {'GPU Core'}
            }
            if (-not $kind) {continue}
            $v=Convert-Number $channel.Value
            if ($null -eq $v) {continue}
            $sample=New-ThermalSample "lhm:$parent" $kind $v 'LibreHardwareMonitor' $sampleAt
            $sample.Id=[string]$channel.Identifier
            $healthSensors+=$sample
        }
    }

    [pscustomobject]@{
        Temperature = $cpuTemperature
        HealthSensors = $healthSensors
        CpuSensor = $cpuSensor
        Gpu = $gpus
        Available = ($sensors.Count -gt 0)
    }
}

function Get-WindowsGpuLoad {
    $engines = @(Get-CimSafe Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine)

    $values = @(
        $engines |
        Where-Object { $_.Name -match 'eng_\d+' } |
        Group-Object { $_.Name -replace '^pid_\d+_', '' } |
        ForEach-Object {
            [math]::Min(
                100,
                [math]::Max(
                    0,
                    ($_.Group | Measure-Object UtilizationPercentage -Sum).Sum
                )
            )
        }
    )

    if ($values.Count) {
        return ($values | Measure-Object -Maximum).Maximum
    }

    return $null
}

function Get-RouteSourceAddress([Net.IPAddress]$destination) {
    $socket = $null
    try {
        # UDP Connect selects a local route. No payload is sent.
        $socket = [Net.Sockets.Socket]::new($destination.AddressFamily,
            [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
        $socket.Connect($destination, 53)
        $socket.LocalEndPoint.Address
    }
    catch { return }
    finally { if ($socket) { $socket.Dispose() } }
}

function Get-NetworkReading {
    param($Cache, [string]$PingTarget)

    $down = $up = $gateway = $adapter = $null
    $candidates = @()
    try {
        foreach ($nic in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($nic.OperationalStatus -ne 'Up' -or $nic.NetworkInterfaceType -eq 'Loopback') { continue }
            try {
                $props = $nic.GetIPProperties()
                $addresses = @($props.UnicastAddresses | ForEach-Object { $_.Address })
                if ($addresses.Count) {
                    $candidates += [pscustomobject]@{ Nic = $nic; Addresses = $addresses; Gateways = $props.GatewayAddresses }
                }
            }
            catch { continue }
        }
    }
    catch { $candidates = @() }

    $selected = $null
    $literal = $null
    $destinations = if ([Net.IPAddress]::TryParse($PingTarget, [ref]$literal)) {
        $literal
    } else {
        [Net.IPAddress]::Parse('1.1.1.1')
        [Net.IPAddress]::Parse('2606:4700:4700::1111')
    }
    foreach ($destination in $destinations) {
        $sourceAddress = Get-RouteSourceAddress $destination
        if ($null -eq $sourceAddress) { continue }
        $selected = $candidates | Where-Object { $_.Addresses -contains $sourceAddress } | Select-Object -First 1
        if ($selected) { break }
    }
    if (-not $selected) {
        $selected = $candidates | Sort-Object { $_.Gateways.Count -gt 0 } -Descending | Select-Object -First 1
    }
    if ($selected) {
        $adapter = $selected.Nic
        $gateways = @($selected.Gateways | ForEach-Object { $_.Address } | Where-Object {
            $_ -and -not $_.Equals([Net.IPAddress]::Any) -and -not $_.Equals([Net.IPAddress]::IPv6Any)
        })
        $gateway = $gateways | Where-Object { $_.AddressFamily -eq $sourceAddress.AddressFamily } | Select-Object -First 1
        if (-not $gateway) { $gateway = $gateways | Select-Object -First 1 }
        try {
            $stats = $adapter.GetIPStatistics()
            $rx = $stats.BytesReceived
            $tx = $stats.BytesSent
            $ticks = [Diagnostics.Stopwatch]::GetTimestamp()
            $previous = $Cache.NetPrevious
            if ($previous -and $previous.Id -eq $adapter.Id -and $rx -ge $previous.Rx -and $tx -ge $previous.Tx) {
                $seconds = ($ticks - $previous.Tick) / [double][Diagnostics.Stopwatch]::Frequency
                if ($seconds -gt 0) {
                    $down = ($rx - $previous.Rx) / $seconds
                    $up = ($tx - $previous.Tx) / $seconds
                }
            }
            $Cache.NetPrevious = @{ Id = $adapter.Id; Rx = $rx; Tx = $tx; Tick = $ticks }
        }
        catch { $Cache.NetPrevious = $null }
    } else {
        $Cache.NetPrevious = $null
    }

    $target = if ($adapter) { if ($PingTarget) { $PingTarget } elseif ($gateway) { $gateway.ToString() } }
    $key = "$($adapter.Id)|$target"
    $now = [datetime]::UtcNow
    if ($Cache.NetProbeKey -ne $key -or ($now - $Cache.PingAt).TotalSeconds -gt 30) {
        $Cache.NetProbeKey = $key
        $Cache.Pings = @()
        $Cache.PingAt = [datetime]::MinValue
        $Cache.Rtt = $null
    }
    if ($target -and ($now - $Cache.PingAt).TotalSeconds -ge 5) {
        $Cache.PingAt = $now
        $Cache.Rtt = $null
        $ping = $null
        try {
            $ping = [Net.NetworkInformation.Ping]::new()
            $reply = $ping.Send($target, 600)
            if ($reply.Status -eq 'Success') {
                $Cache.Rtt = [double]$reply.RoundtripTime
                $Cache.Pings = @( ($Cache.Pings + @($Cache.Rtt)) | Select-Object -Last 10 )
            }
        }
        catch { $Cache.Rtt = $null }
        finally { if ($ping) { $ping.Dispose() } }
        if ($null -eq $Cache.Rtt) { $Cache.Pings = @() }
    }

    $jitter = $null
    if ($Cache.Pings.Count -ge 2) {
        $sum = 0.0
        for ($i = 1; $i -lt $Cache.Pings.Count; $i++) {
            $sum += [math]::Abs($Cache.Pings[$i] - $Cache.Pings[$i - 1])
        }
        $jitter = $sum / ($Cache.Pings.Count - 1)
    }
    [pscustomobject]@{
        Name = $adapter.Name
        DownBps = $down
        UpBps = $up
        Ping = $Cache.Rtt
        Jitter = $jitter
        PingTarget = $target
        Connected = ($null -ne $adapter)
    }
}


# Domain units are observable checks, not failure probabilities.
function New-Condition($name, $status, $reason, $at, $complete = $true) {
    [pscustomobject]@{Name=$name; Status=$status; Reason=$reason; Timestamp=$at; Complete=$complete; Details=$null; Observations=$null; Pressure=$null}
}

function Get-ConfirmedLevel($history, $key, [int]$raw, $at, $gap, $seconds) {
    $h = $history[$key]
    if (-not $h -or $at -lt $h.At -or ($at-$h.At).TotalSeconds -gt $gap) {
        $h = @{ At=$at; Candidate=$raw; Count=0; Level=0; Bands=@(
            @{ Above=$false; Since=$at; Count=0; Confirmed=$false }
            @{ Above=$false; Since=$at; Count=0; Confirmed=$false }
        ) }
        $history[$key]=$h
    } elseif ($at -eq $h.At) { return $h.Level }

    $h.At=$at
    if ($h.Candidate -ne $raw) { $h.Candidate=$raw; $h.Count=0 }
    $h.Count++
    $h.Level=0
    # A critical reading is also above warning. Confirm the two boundaries independently.
    for ($tier=1; $tier -le 2; $tier++) {
        $band=$h.Bands[$tier-1]
        $above=$raw -ge $tier
        if ($band.Above -ne $above) { $band.Above=$above; $band.Since=$at; $band.Count=0 }
        $band.Count++
        $hold=if ($above) { $seconds } else { 2*$seconds }
        if ($band.Count -ge 3 -and ($at-$band.Since).TotalSeconds -ge $hold) { $band.Confirmed=$above }
        if ($band.Confirmed) { $h.Level=$tier }
    }
    $h.Level
}

function Get-ThermalConditionScore($samples, $history, $at, $expectedGpus, $expectedCpus) {
    $worst=0; $cpu=@{}; $gpu=@{}; $scorable=0; $qualified=$true; $generic=$false
    $reasons=@(); $observations=@()
    $margins=@{}
    foreach ($s in $samples) {
        if ($s.Kind -eq 'CPU Margin' -and $null -ne $s.Value -and $s.Value -ge -30 -and $s.Value -le 160) {$margins[$s.Device]=$true}
    }
    $active=@{}
    foreach ($s in $samples) {
        if (-not $s.Id -or $s.Kind -notin @('CPU Package','GPU Core','GPU Hotspot','CPU Margin','GPU Throttle')) { continue }
        if ($null -eq $s.Value -or [double]::IsNaN($s.Value) -or $s.Value -lt -30 -or $s.Value -gt 160) { continue }
        $raw=0
        if ($s.Kind -eq 'CPU Margin') {
            $raw = if ($s.Value -le 0) {2} elseif ($s.Value -le 5) {1} else {0}
        } elseif ($s.Kind -eq 'GPU Throttle') {
            if ($s.Value -notin @(0,1)) {continue}
            $raw=[int]$s.Value
        } elseif ($null -ne $s.Limit -and $s.Limit -gt 0 -and $s.Limit -le 150) {
            $raw = if ($s.Value -ge $s.Limit) {2} elseif ($s.Value -ge ($s.Limit-5)) {1} else {0}
        } elseif ($s.Kind -eq 'CPU Package' -and $margins.ContainsKey($s.Device)) {
            $observations += "$($s.Id) package $($s.Value) C (distance channel used for scoring)"
            continue
        } elseif ($s.Kind -eq 'GPU Hotspot') {
            $observations += "$($s.Id) hotspot $($s.Value) C (limit unknown)"
            continue
        } else {
            $caution = if ($s.Kind -eq 'CPU Package') {90} else {85}
            $raw = [int]($s.Value -ge $caution)
            $qualified=$false; $generic=$true
        }
        $active[$s.Id]=$true
        $scorable++
        if ($s.Kind -like 'CPU*') {$cpu[$s.Device]=$true} else {$gpu[$s.Device]=$true}
        $level=Get-ConfirmedLevel $history $s.Id $raw $s.At $s.Gap $s.Hold
        $observations += "$($s.Device) $($s.Kind)=$($s.Value) [$($s.Source)]"
        if ($history[$s.Id].Count -lt 3 -or $raw -ne $level) {$qualified=$false}
        if ($level) { $reasons += "$($s.Id): sustained thermal indication ($level)" }
        $worst=[math]::Max($worst,$level)
    }
    foreach ($key in @($history.Keys)) {
        if ($key -ne 'Memory' -and -not $active.ContainsKey($key)) {$history.Remove($key)}
    }
    $status=if (-not $scorable) {'Unavailable'} elseif ($worst -eq 2) {'Critical'} elseif ($worst) {'Warning'} else {'Available'}
    $reason=if ($reasons.Count) {$reasons -join '; '} elseif ($scorable) {'No sustained thermal indication in measured channels'} else {'No identified thermal channel'}
    if ($generic) {$reason+='; generic caution only where device limit is unknown'}
    $d=New-Condition Thermal $status $reason $at ($qualified -and $cpu.Count -ge [math]::Max(1,$expectedCpus) -and $gpu.Count -ge $expectedGpus)
    $d.Details=@($samples); $d.Observations=$observations -join '; '
    $d
}

function Get-MemoryCondition($sample,$history,$at) {
    if (-not $sample -or $null -eq $sample.Commit -or $null -eq $sample.Available -or $sample.Total -le 0) {
        return (New-Condition Memory Unavailable 'Commit or physical headroom unavailable' $null $false)
    }
    $free=100.0*$sample.Available/$sample.Total
    $commit=$sample.Commit
    $nearCommitLimit=$sample.CommitLimit -gt 0 -and $null -ne $sample.CommittedBytes -and
        ($sample.CommitLimit-$sample.CommittedBytes) -lt 256MB -and $commit -ge 99
    $raw=if ($nearCommitLimit -or ($commit -ge 97 -and $free -le 3)) {2}
         elseif ($commit -ge 90 -and ($free -le 10 -or ($sample.PageReads -gt 0 -and $free -le 15))) {1}
         else {0}
    $level=Get-ConfirmedLevel $history 'Memory' $raw $sample.At 50 30
    $state=if ($level -eq 2) {'Critical Resource Pressure'} elseif ($level) {'Sustained Pressure'}
           elseif ($raw -or $commit -ge 90) {'Elevated Pressure'} else {'Normal'}
    $status=if ($level -eq 2) {'Critical'} elseif ($level) {'Warning'} else {'Available'}
    $d=New-Condition Memory $status ("{0}: {1:N0}% commit, {2:N1}% physical available" -f $state,$commit,$free) $sample.At
    $d.Complete=($history.Memory.Count -ge 3 -and $level -eq $raw)
    $d.Details=$sample
    $d.Pressure=$state
    $d
}

function Get-StorageHealthSummary($disks,$counters,$at) {
    $ids=@{}; $rel=@{}; $items=@()
    foreach ($d in $disks) { $ids[[string]$d.DeviceId]++ }
    foreach ($r in $counters) {
        $k=[string]$r.DeviceId
        if ($rel.ContainsKey($k)) { $rel[$k]=$null } else { $rel[$k]=$r }
    }
    foreach ($d in $disks) {
        $health=[string]$d.HealthStatus
        $opCodes=$d.OperationalStatus
        if ($d.CimInstanceProperties) {
            $health=[string]$d.CimInstanceProperties['HealthStatus'].Value
            $opCodes=$d.CimInstanceProperties['OperationalStatus'].Value
        }
        $ops=@($opCodes | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
        # DMTF OperationalStatus: Error, Non-Recoverable Error, Predictive Failure.
        $bad=@($ops | Where-Object { $_ -eq 7 }).Count
        $warn=@($ops | Where-Object { $_ -in @(3,4,5,6,12,13,16) }).Count
        $operOk=$ops.Count -gt 0 -and @($ops | Where-Object { $_ -notin @(2,15) }).Count -eq 0
        $state=if ($health -in @('2','Unhealthy') -or $bad) {'Unhealthy'}
               elseif ($health -in @('1','Warning') -or $warn) {'Warning'}
               elseif ($health -in @('0','Healthy') -and $operOk) {'Healthy'} else {'Unknown'}
        $counter=if ([string]$d.DeviceId -ne '' -and $ids[[string]$d.DeviceId] -eq 1) {$rel[[string]$d.DeviceId]}
        $items += [pscustomobject]@{Id=$d.ObjectId; DeviceId=$d.DeviceId; Name=$d.FriendlyName; Bus=$d.BusType
            HealthStatus=$health; OperationalStatus=$ops; State=$state; Reliability=$(if ($counter) {
                [pscustomobject]@{Temperature=$counter.Temperature; Wear=$counter.Wear; ReadErrorsUncorrected=$counter.ReadErrorsUncorrected; WriteErrorsUncorrected=$counter.WriteErrorsUncorrected}
            })}
    }
    $known=@($items | Where-Object State -ne Unknown).Count
    $states=@($items | ForEach-Object State)
    $status=if ('Unhealthy' -in $states) {'Critical'} elseif ('Warning' -in $states) {'Warning'} elseif ($known) {'Available'} else {'Unavailable'}
    $reason=if ($items.Count) { ($items | ForEach-Object {"$($_.Name) [$($_.DeviceId)] $($_.State)"}) -join '; ' } else {'No physical disks reported'}
    $d=New-Condition Storage $status $reason $at ($known -gt 0 -and $known -eq $items.Count)
    $d.Details=$items; $d
}

function Get-WheaClassification($eventId,$level,$raw,$message) {
    # CPER record header (UEFI spec, Common Platform Error Record).
    if ($raw -match '^43504552[0-9a-f]{4}FFFFFFFF' -and $raw.Length -ge 256 -and $raw.Length % 2 -eq 0) {
        $header=New-Object byte[] 24
        for ($i=0;$i -lt 24;$i++) {$header[$i]=[Convert]::ToByte($raw.Substring(2*$i,2),16)}
        $bytes=[BitConverter]::ToUInt32($header,20)
        $sections=[BitConverter]::ToUInt16($header,10)
        if ($sections -gt 0 -and $bytes -ge (128 + 72*$sections) -and $bytes -le $raw.Length/2) {
            switch ([BitConverter]::ToUInt32($header,12)) {
                0 {return 'Uncorrected'} 1 {return 'Fatal'} 2 {return 'Corrected'} 3 {return 'Informational'}
            }
        }
    }
    if ($level -in @(1,2) -and $message -match '(?i)\bfatal hardware error\b') {return 'Fatal'}
    if ($level -in @(1,2) -and $message -match '(?i)\buncorrect(ed|able)\b') {return 'Uncorrected'}
    if ($level -in @(3,4) -and $message -match '(?i)\bcorrected hardware error\b') {return 'Corrected'}
    'Unclassified'
}

function Get-WheaCondition($events,$at,$backlog) {
    $events=@($events | Where-Object { $_ -and $_.Time -ge $at.AddHours(-1) })
    $critical=@($events | Where-Object { $_.Class -in @('Fatal','Uncorrected') }).Count
    $corrected=@($events | Where-Object Class -eq Corrected).Count
    $unknown=@($events | Where-Object Class -eq Unclassified).Count
    $status=if ($critical) {'Critical'} elseif ($corrected -gt 1) {'Warning'} elseif ($unknown -or $backlog) {'Unavailable'} else {'Available'}
    $reason="WHEA 1h: $critical fatal/uncorrected, $corrected corrected, $unknown unclassified"
    if ($backlog) {$reason+='; catch-up pending'}
    $d=New-Condition WHEA $status $reason $at (-not $unknown -and -not $backlog)
    $d.Details=$events; $d
}

function Get-OperatingEstimate($thermal,$memory,$storage,$whea,$at) {
    $categories=[ordered]@{Thermal=$thermal;Memory=$memory;Storage=$storage;WHEA=$whea}
    $known=0; $passed=0; $complete=0; $fatal=$false; $attention=$false; $warning=$false; $reasons=@()
    foreach ($c in $categories.Values) {
        if ($c.Status -in @('Available','Warning','Critical')) {
            $known++
            if ($c.Complete) {$complete++}
            if ($c.Status -eq 'Available') {$passed+=2}
            elseif ($c.Status -eq 'Warning') {$passed++; $warning=$true}
            else { $attention=$true; if ($c.Name -in @('Storage','WHEA')) { $fatal=$true } }
        }
        $reasons += "$($c.Name): $($c.Reason)"
    }
    $unresolved=$false
    foreach ($c in $categories.Values) {
        if ($c.Status -eq 'Stale' -and $c.Details.Status -in @('Critical','Warning')) {$unresolved=$true}
    }
    $score=$null
    if ($known -ge 3 -and -not $unresolved) {
        $score=[int][math]::Round(100*$passed/(2*$known))
        if ($fatal) {$score=[math]::Min($score,49)}
    }
    $status=if ($attention) {'ATTENTION'} elseif ($warning -or $unresolved) {'CHECK'} elseif ($null -eq $score) {'INSUFFICIENT DATA'}
            elseif ($complete -eq 4) {'EXCELLENT'} else {'GOOD'}
    [pscustomobject]@{Score=$score;Status=$status;Reasons=$reasons;Timestamp=$at;DataCoverage="$known/4";CompleteDomains=$complete
        Confidence=$(if ($known -lt 3) {'Low'} elseif ($complete -eq 4) {'High'} else {'Limited'})
        Critical=$attention;LastQueryMs=$null;Categories=$categories;HardwareHealth=@($storage,$whea);OperatingCondition=@($thermal,$memory)}
}

function Read-LogAnchor($filter,[bool]$newest=$true) {
    $q=[System.Diagnostics.Eventing.Reader.EventLogQuery]::new('System',[System.Diagnostics.Eventing.Reader.PathType]::LogName,$filter)
    $q.ReverseDirection=$newest
    $r=[System.Diagnostics.Eventing.Reader.EventLogReader]::new($q)
    try {
        $e=$r.ReadEvent()
        if ($e) {try { [pscustomobject]@{Id=[long]$e.RecordId; Time=$e.TimeCreated.ToUniversalTime()} } finally {$e.Dispose()}}
    } finally {$r.Dispose()}
}

function Read-HealthWhea($cache,$now) {
    $provider='Microsoft-Windows-WHEA-Logger'
    if (-not $cache.ProviderChecked) {
        $meta=[System.Diagnostics.Eventing.Reader.ProviderMetadata]::new($provider)
        try { $cache.ProviderChecked=($meta.Name -eq $provider) } finally {$meta.Dispose()}
    }
    $head=Read-LogAnchor '*'
    $oldest=Read-LogAnchor '*' $false
    $cursor=$cache.Cursor
    $events=@($cache.Events | Where-Object { $_ -and $_.Time -ge $now.AddHours(-1) })
    if ($cursor) {
        $anchor=Read-LogAnchor "*[System[EventRecordID=$($cursor.Id)]]"
        if (-not $anchor -or $anchor.Time -ne $cursor.Time) {$cursor=$null; $events=@()}
    }
    $pending=$false
    if ($head -and (-not $cursor -or $head.Id -gt $cursor.Id)) {
        $start=if ($cursor) {$cursor.Id} else {0}
        $filter="*[System[Provider[@Name='$provider'] and EventRecordID > $start and EventRecordID <= $($head.Id) and TimeCreated[timediff(@SystemTime) <= 3600000]]]"
        $q=[System.Diagnostics.Eventing.Reader.EventLogQuery]::new('System',[System.Diagnostics.Eventing.Reader.PathType]::LogName,$filter)
        $r=[System.Diagnostics.Eventing.Reader.EventLogReader]::new($q)
        try {
            for ($i=0;$i -lt 32;$i++) {
                $e=$r.ReadEvent()
                if (-not $e) {break}
                try {
                    $xml=[xml]$e.ToXml()
                    $raw=$xml.SelectSingleNode("//*[local-name()='Data' and @Name='RawData']")
                    $class=Get-WheaClassification $e.Id $e.Level $raw.InnerText ''
                    if ($class -eq 'Unclassified') {
                        $msg=try {$e.FormatDescription()} catch {''}
                        $class=Get-WheaClassification $e.Id $e.Level '' $msg
                    }
                    $when=$e.TimeCreated.ToUniversalTime()
                    $cursor=[pscustomobject]@{Id=[long]$e.RecordId;Time=$when}
                    $events += [pscustomobject]@{RecordId=$e.RecordId; EventId=$e.Id; Level=$e.Level;Time=$when;Class=$class}
                } finally {$e.Dispose()}
            }
            $pending=$i -eq 32
        } finally {$r.Dispose()}
    }
    if (-not $pending) {$cursor=$head}
    # Keep recent evidence per severity even during a corrected-event storm.
    $events=@(foreach ($group in ($events | Group-Object Class)) {$group.Group | Select-Object -Last 32})
    $result=Get-WheaCondition $events $now $pending
    if (-not $oldest -or $oldest.Time -gt $now.AddHours(-1)) {
        $result.Complete=$false
        $result.Reason+='; retained System log covers less than one hour'
        if ($result.Status -eq 'Available') {$result.Status='Unavailable'}
    }
    $cache.Cursor=$cursor; $cache.Events=$events
    $result
}

function Read-HealthMemory($os,$now) {
    $m=Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory -OperationTimeoutSec 2 -ErrorAction Stop
    $total=[double]$os.TotalVisibleMemorySize*1KB
    $free=$m.AvailableBytes
    if ($null -eq $free -and $null -ne $os.FreePhysicalMemory) {$free=[double]$os.FreePhysicalMemory*1KB}
    $commit=$m.PercentCommittedBytesInUse
    if ($null -ne $m.CommittedBytes -and $m.CommitLimit -gt 0) {$commit=100.0*$m.CommittedBytes/$m.CommitLimit}
    if ($total -le 0 -or $null -eq $free -or $free -lt 0 -or $free -gt $total -or $null -eq $commit -or $commit -lt 0 -or $commit -gt 100) {throw 'Inconsistent or missing Windows memory counters'}
    [pscustomobject]@{At=$now;Total=$total;Available=$free;Commit=$commit;CommittedBytes=$m.CommittedBytes;CommitLimit=$m.CommitLimit;PageReads=$m.PageReadsPersec}
}

function Read-HealthStorage($now,$context) {
    $ns='root/Microsoft/Windows/Storage'
    $disks=@(Get-CimInstance -ClassName MSFT_PhysicalDisk -Namespace $ns -OperationTimeoutSec 2 -ErrorAction Stop)
    if (-not $disks.Count) {throw 'Physical disk inventory is empty'}
    $counters=try {@(Get-CimInstance -ClassName MSFT_StorageReliabilityCounter -Namespace $ns -OperationTimeoutSec 2 -ErrorAction Stop)} catch {@()}
    $summary=Get-StorageHealthSummary $disks $counters $now
    $queue=@()
    $attempts=@{}
    $retained=@{}
    for ($i=0;$i -lt $disks.Count;$i++) {
        # Each row was created directly from this same physical CIM object above.
        $physical=$disks[$i]; $row=$summary.Details[$i]; $id=[string]$physical.ObjectId
        if (-not $id -or $row.Reliability) {continue}
        if ($context.DiskAttempts.ContainsKey($id)) {$attempts[$id]=$context.DiskAttempts[$id]}
        $cached=$context.Reliability[$id]
        if ($cached -and $now -ge $cached.At -and ($now-$cached.At).TotalMinutes -lt 10) {
            $row.Reliability=$cached; $retained[$id]=$cached
        } else {$queue+=$physical}
    }
    $context.Reliability=$retained
    $context.DiskAttempts=$attempts
    $context.PendingDisks=@($queue | Sort-Object {
        $last=$context.DiskAttempts[[string]$_.ObjectId]
        if ($last) {$last} else {[datetime]::MinValue}
    })
    $summary
}

function Read-NvidiaThermalPolicy($exe,$at) {
    $p=[Diagnostics.Process]::new()
    $p.StartInfo.FileName=$exe; $p.StartInfo.Arguments='-q -x'
    $p.StartInfo.UseShellExecute=$false; $p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardOutput=$true; $p.StartInfo.RedirectStandardError=$true
    try {
        [void]$p.Start()
        $stdout=$p.StandardOutput.ReadToEndAsync(); $err=$p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(1000)) {$p.Kill(); throw 'NVIDIA health query timed out'}
        if ($p.ExitCode -ne 0) {throw 'NVIDIA thermal policy unavailable'}
        $doc=[xml]::new(); $doc.XmlResolver=$null; $doc.LoadXml($stdout.Result)
        $map=@{}
        foreach ($g in $doc.nvidia_smi_log.gpu) {
            if (-not $g.uuid) {continue}
            $limit=$null; $throttle=$null
            if ([string]$g.temperature.gpu_max_operating_temp -match '^([1-9][0-9]{1,2}) C$') {$limit=[int]$Matches[1]}
            $flags=@($g.SelectNodes('.//clocks_event_reason_hw_thermal_slowdown | .//clocks_throttle_reason_hw_thermal_slowdown | .//clocks_event_reason_sw_thermal_slowdown | .//clocks_throttle_reason_sw_thermal_slowdown') | ForEach-Object {$_.InnerText})
            if ('Active' -in $flags) {$throttle=1} elseif ('Not Active' -in $flags) {$throttle=0}
            if ($null -ne $limit -or $null -ne $throttle) {$map['nv:'+[string]$g.uuid]=@{Limit=$limit;Throttle=$throttle;At=$at}}
        }
        if (-not $map.Count) {throw 'No supported NVIDIA thermal flags or absolute operating limits'}
        $map
    } finally {$p.Dispose()}
}

function New-ThermalSample($device,$kind,$value,$source,$at,$limit=$null) {
    [pscustomobject]@{Id="$device/$kind";Device=$device;Kind=$kind;Value=$value;Source=$source;At=$at;Limit=$limit;Gap=18;Hold=10}
}

function Get-HealthV2($cache,$os,$sensor,$cards,$now,$smi,$inventory) {
    if (-not $cache.HealthV2) {
        $slots=@{}
        foreach ($p in @('Memory','Storage','WHEA','Nvidia','Thermal','Reliability')) {
            $slots[$p]=@{Next=[datetime]::MinValue;At=[datetime]::MinValue;Last=$null;Failures=0;Error=''}
        }
        $cache.HealthV2=@{Slots=$slots;History=@{};Log=@{};Reliability=@{};DiskAttempts=@{};PendingDisks=@();Last=[datetime]::MinValue}
    }
    $h=$cache.HealthV2
    if ($now -lt $h.Last -or ($now-$h.Last).TotalSeconds -gt 45) {
        $h.History=@{}; $h.Slots.Memory.Evaluated=$null
        foreach ($slot in $h.Slots.Values) {$slot.Next=$now; if ($slot.At -gt $now) {$slot.At=[datetime]::MinValue;$slot.Last=$null}}
    }
    $h.Last=$now
    # At most one health-specific provider per shared worker pass.
    foreach ($provider in @('Memory','WHEA','Storage','Nvidia','Reliability')) {
        $slot=$h.Slots[$provider]
        if ($now -lt $slot.Next -or ($provider -eq 'Nvidia' -and -not $smi)) {continue}
        if ($provider -eq 'Reliability' -and (-not $h.PendingDisks.Count -or $h.Slots.Storage.Failures)) {continue}
        $period=@{Memory=15;Storage=120;WHEA=60;Nvidia=60;Reliability=30}[$provider]
        $started=[Diagnostics.Stopwatch]::GetTimestamp()
        try {
            $newValue=switch ($provider) {
                Memory {Read-HealthMemory $os $now}
                Storage {Read-HealthStorage $now $h}
                Reliability {
                    $device=$h.PendingDisks[0]
                    $h.PendingDisks=@($h.PendingDisks | Select-Object -Skip 1)
                    $h.DiskAttempts[[string]$device.ObjectId]=$now
                    $reply=Invoke-CimMethod -InputObject $device -MethodName GetStorageReliabilityCounter -OperationTimeoutSec 2 -ErrorAction Stop
                    if ($null -eq $reply.ReturnValue -or $reply.ReturnValue -ne 0 -or -not $reply.StorageReliabilityCounter) {throw 'Reliability method unsupported'}
                    $counter=$reply.StorageReliabilityCounter
                    $h.Reliability[[string]$device.ObjectId]=[pscustomobject]@{At=$now;Temperature=$counter.Temperature;Wear=$counter.Wear
                        ReadErrorsUncorrected=$counter.ReadErrorsUncorrected;WriteErrorsUncorrected=$counter.WriteErrorsUncorrected}
                    $true
                }
                WHEA {Read-HealthWhea $h.Log $now}
                Nvidia {Read-NvidiaThermalPolicy $smi $now}
            }
            $slot.Last=$newValue; $slot.At=$now; $slot.Failures=0; $slot.Error=''
            if ($provider -eq 'WHEA' -and $newValue.Reason -like '*catch-up pending*') {$period=5}
        } catch {
            $slot.Error=$_.Exception.Message; $slot.Failures=[math]::Min(4,$slot.Failures+1)
            $period=[math]::Min(300,$period*[math]::Pow(2,$slot.Failures-1))
        }
        $slot.DurationMs=[math]::Round(1000.0*([Diagnostics.Stopwatch]::GetTimestamp()-$started)/[Diagnostics.Stopwatch]::Frequency,2)
        $slot.Next=$now.AddSeconds($period)
        break
    }
    $nv=$h.Slots.Nvidia
    $samples=@($sensor.HealthSensors)
    foreach ($g in $cards) {
        if ($g.Source -ne 'NVIDIA driver' -or $null -eq $g.Temp) {continue}
        $policy=if ($nv.Last -and ($now-$nv.At).TotalSeconds -le 130) {$nv.Last[$g.Id]}
        $samples+=New-ThermalSample $g.Id 'GPU Core' $g.Temp 'NVIDIA driver' $now $policy.Limit
        if ($null -ne $policy.Throttle -and -not $nv.Failures) {
            $f=New-ThermalSample $g.Id 'GPU Throttle' $policy.Throttle 'NVIDIA driver' $policy.At
            $f.Gap=140;$f.Hold=60;$samples+=$f
        }
    }
    # Duplicate providers can see the same GPU. Coverage uses inventory IDs, never display names alone.
    $thermal=Get-ThermalConditionScore $samples $h.History $now @($inventory.Adapters).Count $inventory.CpuCount
    $lhmGpu=$false; $nvGpu=$false
    foreach ($s in $samples) {
        if ($s.Kind -ne 'GPU Core') {continue}
        if ($s.Device -like 'lhm:*') {$lhmGpu=$true}
        if ($s.Device -like 'nv:*') {$nvGpu=$true}
    }
    if ($lhmGpu -and $nvGpu) {$thermal.Complete=$false}
    $tSlot=$h.Slots.Thermal
    if ($thermal.Status -ne 'Unavailable') {$tSlot.Last=$thermal;$tSlot.At=$now}
    $categories=@{}
    foreach ($name in @('Memory','Storage','WHEA','Thermal')) {
        $slot=$h.Slots[$name]
        $ttl=@{Memory=45;Thermal=15;Storage=300;WHEA=150}[$name]
        $ok=$slot.Last -and ($now-$slot.At).TotalSeconds -le $ttl -and -not $slot.Failures
        if ($name -eq 'Thermal' -and $thermal.Status -eq 'Unavailable') {$ok=$false}
        if ($ok) {
            if ($name -eq 'Memory') {
                if (-not $slot.Evaluated -or $slot.Evaluated.Timestamp -ne $slot.At) {
                    $slot.Evaluated=Get-MemoryCondition $slot.Last $h.History $now
                }
                $categories[$name]=$slot.Evaluated
            } else {$categories[$name]=$slot.Last}
        } else {
            $why=if ($slot.Error) {$slot.Error} else {'No fresh evidence'}
            $state=if ($slot.Last) {'Stale'} else {'Unavailable'}
            $c=New-Condition $name $state $why $slot.At $false
            if ($slot.Last) {
                $c.Details=$slot.Last
                $c.Reason+="; last successful sample $($slot.At.ToString('u'))"
                if ($slot.Last.Reason) {$c.Reason+=": $($slot.Last.Reason)"}
            }
            $categories[$name]=$c
        }
    }
    $estimate=Get-OperatingEstimate $categories.Thermal $categories.Memory $categories.Storage $categories.WHEA $now
    $timings=@{}
    foreach ($name in @('Memory','Storage','WHEA','Nvidia','Reliability')) {$timings[$name]=$h.Slots[$name].DurationMs}
    $estimate.LastQueryMs=$timings
    $estimate
}

function Get-Telemetry {
    param($Config)

    if (-not $global:TelemetryCache) {
        $smi = $null

        try {
            $smi = Get-Command nvidia-smi.exe -CommandType Application -ErrorAction Stop |
                Select-Object -First 1
        }
        catch {}

        $candidate = if ($smi) {
            $smi.Source
        }
        elseif ($env:SystemRoot) {
            Join-Path $env:SystemRoot 'System32/nvidia-smi.exe'
        }
        else {
            ''
        }

        if ($candidate -and -not (Test-Path -LiteralPath $candidate)) {
            $candidate = ''
        }

        $global:TelemetryCache = @{
            Inventory = $null
            InventoryAt = [datetime]::MinValue
            Disks = @()
            DiskAt = [datetime]::MinValue
            Smi = $candidate
            Pings = @()
            PingAt = [datetime]::MinValue
            Rtt = $null
        }
    }

    $cache = $global:TelemetryCache
    $now = [datetime]::UtcNow

    if (-not $cache.Inventory -or ($now - $cache.InventoryAt).TotalSeconds -ge 60) {
        $cache.Inventory = Get-Inventory
        $cache.InventoryAt = $now
    }

    $os = @(Get-CimSafe Win32_OperatingSystem) | Select-Object -First 1
    $cpu = @(Get-CimSafe Win32_PerfFormattedData_PerfOS_Processor "Name='_Total'") |
        Select-Object -First 1

    $cpuLoad = Convert-Number $cpu.PercentProcessorTime

    if ($null -eq $cpuLoad) {
        $fallback = @(
            Get-CimSafe Win32_Processor |
            Where-Object { $null -ne $_.LoadPercentage }
        )

        if ($fallback.Count) {
            $cpuLoad = ($fallback | Measure-Object LoadPercentage -Average).Average
        }
    }

    if ($null -ne $cpuLoad) {
        $cpuLoad = [math]::Min(100, [math]::Max(0, $cpuLoad))
    }

    $memoryUsed = $null
    $memoryTotal = $null
    $memoryPct = $null
    $uptime = $null

    if ($os -and $os.TotalVisibleMemorySize -gt 0) {
        $memoryTotal = [double]$os.TotalVisibleMemorySize * 1KB
        $memoryUsed = $memoryTotal - [double]$os.FreePhysicalMemory * 1KB
        $memoryPct = 100 * $memoryUsed / $memoryTotal

        if ($os.LastBootUpTime) {
            $uptime = ((Get-Date) - $os.LastBootUpTime).TotalSeconds
        }
    }

    $sensor = Get-SensorData $Config.HealthActive
    $gpus = @(Invoke-NvidiaQuery $cache.Smi)
    $gpuKeys = @($gpus | ForEach-Object { Normalize-GpuName $_.Name })

    foreach ($g in $sensor.Gpu) {
        if ((Normalize-GpuName $g.Name) -notin $gpuKeys) {
            $gpus += $g
        }
    }

    $gpuKeys = @($gpus | ForEach-Object { Normalize-GpuName $_.Name })
    $windowsLoad = Get-WindowsGpuLoad

    if ($null -ne $windowsLoad) {
        $gpus += [pscustomobject]@{
            Id = 'windows:all'
            Name = 'All adapters / busiest engine'
            Load = $windowsLoad
            Temp = $null
            UsedMB = $null
            TotalMB = $null
            Source = 'Windows GPU engine counters'
            Kind = 'aggregate'
        }
    }

    foreach ($adapter in $cache.Inventory.Adapters) {
        if ((Normalize-GpuName $adapter.Name) -notin $gpuKeys) {
            $gpus += [pscustomobject]@{
                Id = $adapter.Id
                Name = $adapter.Name
                Load = $null
                Temp = $null
                UsedMB = $null
                TotalMB = $null
                Source = 'Windows inventory / metrics unavailable'
                Kind = 'adapter'
            }
        }
    }

    if (($now - $cache.DiskAt).TotalSeconds -ge 15) {
        $cache.Disks = @(
            Get-CimSafe Win32_LogicalDisk 'DriveType=3' |
            Where-Object { $_.Size -gt 0 } |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.DeviceID
                    Label = $_.VolumeName
                    Total = [double]$_.Size
                    Free = if ($null -ne $_.FreeSpace) { [double]$_.FreeSpace } else { $null }
                    UsedPercent = 100 * ([double]$_.Size - [double]$_.FreeSpace) / [double]$_.Size
                }
            }
        )
        $cache.DiskAt = $now
    }

    $health=$null
    if ($Config.HealthActive) {
        try { $health=Get-HealthV2 $cache $os $sensor $gpus ([datetime]::UtcNow) $cache.Smi $cache.Inventory }
        catch {
            $fault=$_.Exception.Message; $at=[datetime]::UtcNow
            $failed=@(foreach ($category in @('Thermal','Memory','Storage','WHEA')) {New-Condition $category Unavailable $fault $at $false})
            $health=Get-OperatingEstimate $failed[0] $failed[1] $failed[2] $failed[3] $at
        }
    }

    $processes = $null
    try { $processes = @(Get-Process -ErrorAction Stop).Count }
    catch {}

    [pscustomobject]@{
        Timestamp = Get-Date
        Inventory = $cache.Inventory
        OS = $os.Caption
        Cpu = $cpuLoad
        MemoryUsed = $memoryUsed
        MemoryTotal = $memoryTotal
        MemoryPercent = $memoryPct
        UptimeSeconds = $uptime
        Processes = $processes
        Gpus = $gpus
        HealthV2 = $health
        CpuTemperature = $sensor.Temperature
        CpuSensor = $sensor.CpuSensor
        SensorAvailable = $sensor.Available
        Disks = $cache.Disks
        Network = (Get-NetworkReading $cache $Config.PingTarget)
    }
}
'@

[void]$worker.AddScript($providerSource)
[void]$worker.Invoke()

if ($worker.HadErrors) {
    $worker.Dispose()
    $runspace.Dispose()
    throw 'Unable to initialize telemetry providers.'
}

$worker.Commands.Clear()

function Restore-HealthView {
    if ($state.Closing -or -not $ui.HomePage.IsVisible -or $window.WindowState -eq [Windows.WindowState]::Minimized) { return }
    if ($null -ne $script:LastHealthResult) {
        Update-SystemHealth $script:LastHealthResult -Immediate
        $age=([datetime]::UtcNow-$script:LastHealthResult.Timestamp).TotalSeconds
        if ($age -ge 0 -and $age -le 15) { return }
    }
    # An outstanding read completes normally; its next scheduled pass runs on HOME.
    if ($null -eq $state.Pending -and ((Get-Date)-$state.Started).TotalMilliseconds -ge $script:Config.RefreshMs) {
        Start-Reading
    }
}

function Start-Reading {
    if ($state.Closing -or $null -ne $state.Pending) { return }

    $state.Started = Get-Date
    $worker.Commands.Clear()
    $worker.Streams.Error.Clear()

    $options=$script:Config.Clone()
    $elapsedMs=$meterSampleClock.Elapsed.TotalMilliseconds
    $onHome=$ui.HomePage.IsVisible -and $window.WindowState -ne [Windows.WindowState]::Minimized
    $options.HealthActive=$onHome -or ($elapsedMs-$script:LastHealthRequestMs -ge 8000)
    if ($options.HealthActive) { $script:LastHealthRequestMs=$elapsedMs }
    [void]$worker.AddCommand('Get-Telemetry').AddParameter(
        'Config',
        $options
    )

    $state.Pending = $worker.BeginInvoke()
}

$ui.Close.Add_Click({
    $window.Close()
})

$ui.Minimize.Add_Click({
    $window.WindowState = [Windows.WindowState]::Minimized
})

# Shared, composited Fade In + rise entrance for every content destination.
# Attach to ContentPages, not HomePage, so upcoming categories inherit it.
# Animation clocks run in WPF; no PowerShell per-frame polling/timer.
$script:PageContentSurface = $window.FindName('ContentPages')
$script:PageContentOffset = [Windows.Media.TranslateTransform]::new(0.0, 0.0)
$script:PageContentSurface.RenderTransform = $script:PageContentOffset
$script:PageContentSurface.Opacity = 1.0
$script:SelectedScriptXPage = $null
function Start-ScriptXPageEntrance {
    param([switch]$Initial)
    if ($null -eq $script:PageContentSurface) { return }
    try {
        $page = $script:PageContentSurface
        $offset = $script:PageContentOffset
        # Reset the old clocks on rapid category switches, keeping an opaque
        # base/zero offset as a safe fallback if animation initialization fails.
        $page.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
        $offset.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $null)
        $page.Opacity = 1.0
        $offset.Y = 0.0

        # Calm, slightly staggered composition: opacity grows through most of
        # the rise rather than appearing instantly. WPF clocks do the work;
        # no new DispatcherTimer and no CPU-side animation loop.
        $durationMs = if ($Initial) { 850 } else { 740 }
        $fadeDurationMs = if ($Initial) { 760 } else { 680 }
        $startY = if ($Initial) { 27.0 } else { 23.0 }
        $riseEase = New-Object Windows.Media.Animation.CubicEase
        $riseEase.EasingMode = [Windows.Media.Animation.EasingMode]::EaseOut
        $fadeEase = New-Object Windows.Media.Animation.SineEase
        $fadeEase.EasingMode = [Windows.Media.Animation.EasingMode]::EaseInOut

        $rise = New-Object Windows.Media.Animation.DoubleAnimation
        $rise.From = $startY
        $rise.To = 0.0
        $rise.Duration = [Windows.Duration]::new([timespan]::FromMilliseconds($durationMs))
        $rise.EasingFunction = $riseEase
        $rise.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop

        $fade = New-Object Windows.Media.Animation.DoubleAnimation
        $fade.From = 0.0
        $fade.To = 1.0
        $fade.Duration = [Windows.Duration]::new([timespan]::FromMilliseconds($fadeDurationMs))
        $fade.EasingFunction = $fadeEase
        $fade.FillBehavior = [Windows.Media.Animation.FillBehavior]::Stop

        $offset.BeginAnimation(
            [Windows.Media.TranslateTransform]::YProperty, $rise,
            [Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
        $page.BeginAnimation(
            [Windows.UIElement]::OpacityProperty, $fade,
            [Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
    }
    catch {
        # A decorative page transition must never blank the dashboard.
        $script:PageContentOffset.Y = 0.0
        $script:PageContentSurface.Opacity = 1.0
    }
}

# All sidebar destinations work. Non-Home categories deliberately have
# empty content for now; they do not call placeholder dialogs or run tweaks.
$script:NavSelectedBg = $window.FindResource('NavSelectedGlass')
$script:NavSelectedFg = [Windows.Media.BrushConverter]::new().ConvertFromString('#F7FAFF')
$script:NavIdleFg = [Windows.Media.BrushConverter]::new().ConvertFromString('#B6C7D9')
function Set-ScriptXPage {
    param([ValidateSet('Home','Boost','Latency','Network','Cleanup')][string]$Name)

    if ($Name -eq $script:SelectedScriptXPage) { return }
    $script:SelectedScriptXPage = $Name
    $homeSelected = $Name -eq 'Home'
    $ui.HomePage.Visibility = if ($homeSelected) {
        [Windows.Visibility]::Visible
    } else {
        [Windows.Visibility]::Collapsed
    }
    $ui.BlankPage.Visibility = if ($homeSelected) {
        [Windows.Visibility]::Collapsed
    } else {
        [Windows.Visibility]::Visible
    }
    if ($null -ne $script:FpsFramePresenter) {
        $script:FpsFramePresenter.SetVisible([bool]($homeSelected -and
            $script:UiInitialized -and
            $window.WindowState -eq [Windows.WindowState]::Normal))
    }
    foreach ($navName in @('Home','Boost','Latency','Network','Cleanup')) {
        $active = $navName -eq $Name
        $ui[$navName].Background = if ($active) {
            $script:NavSelectedBg
        } else {
            [Windows.Media.Brushes]::Transparent
        }
        $ui[$navName].Foreground = if ($active) {
            $script:NavSelectedFg
        } else {
            $script:NavIdleFg
        }
    }
    if ($homeSelected -and $script:UiInitialized) { Restore-HealthView }
    # Preserve category/page-content transitions (not window zoom).
    if ($script:UiInitialized) { Start-ScriptXPageEntrance }
}
$ui.Home.Add_Click({ Set-ScriptXPage -Name 'Home' })
foreach ($navName in @('Boost','Latency','Network','Cleanup')) {
    $ui[$navName].Add_Click({
        param($sender, $eventArgs)
        Set-ScriptXPage -Name ([string]$sender.Name)
    })
}
Set-ScriptXPage -Name 'Home' 

# FPS presentation only: capture runs in independent background workers.
# The FPS numeral and arc are drawn from the SAME smoothed display value.
# This is presentation interpolation, not a new measured FPS sample; statistics
# and engine diagnostics continue to use only unmodified frame measurements.
$script:FpsGaugePreviousValue = -1.0
$script:FpsGaugeLevel = 0.0
$script:FpsGaugeShownOpacity = -1.0
function Update-FpsRingProgress {
    # The native WPF frame callback owns the FPS ring. This function is only
    # kept for fallback on systems where C# presentation cannot initialize.
    if ($null -ne $script:FpsFramePresenter) { Write-FpsUiDiagnostic; return }
    try {
        if ($ui.HomePage.Visibility -ne [Windows.Visibility]::Visible) { return }
        $ring = $ui.FpsRingProgress
        if ($null -eq $ring) { return }

        $fpsValue = [double]$script:FpsGaugeVisualValue
        # Preserve the original gauge scale of 0..360 FPS. This is a fill
        # ratio (0..100% of the arc), not an FPS percentage or fabricated data.
        $level = if ($fpsValue -gt 0.0) {
            if ($script:FpsGaugeExiting) {
                [math]::Min(1.0, $fpsValue / 360.0)
            } else { [math]::Max(0.06, [math]::Min(1.0, $fpsValue / 360.0)) }
        } else { 0.0 }
        $targetOpacity = if ($fpsValue -le 0.0) { 0.0 } elseif ($script:FpsGaugeIsHeld) { 0.65 } else { 1.0 }
        if ([math]::Abs($targetOpacity - $script:FpsGaugeShownOpacity) -ge 0.01) {
            $script:FpsGaugeShownOpacity = $targetOpacity
            $fade = New-Object Windows.Media.Animation.DoubleAnimation
            $fade.From = [double]$ring.Opacity
            $fade.To = [double]$targetOpacity
            $fade.Duration = [Windows.Duration]::new([timespan]::FromMilliseconds(260))
            $ring.BeginAnimation(
                [Windows.UIElement]::OpacityProperty,
                $fade,
                [Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace)
        }

        if ([math]::Abs($fpsValue - $script:FpsGaugePreviousValue) -lt 0.04 -and
            [math]::Abs($level - $script:FpsGaugeLevel) -lt 0.0001) { return }
        $script:FpsGaugePreviousValue = $fpsValue
        if ([math]::Abs($level - $script:FpsGaugeLevel) -lt 0.0001) { return }
        $script:FpsGaugeLevel = $level
        # Set the offset on the 33ms shared clock rather than restarting a
        # separate 180ms animation every time a 250ms telemetry sample arrives.
        $ring.StrokeDashOffset = [double](43.93 * (1.0 - $level))
    }
    catch {
        # Gauge decoration must never interfere with genuine FPS sampling.
    }
    finally { Write-FpsUiDiagnostic }
}

function Update-SmoothFpsGauge {
    if ($null -ne $script:FpsFramePresenter) { return }
    # Fallback when native WPF rendering cannot be initialized.
    # A velocity-preserving critically damped transition avoids the previous
    # per-tick max-step clamp (which made the ring fall behind and then jump).
    # Neither this function nor the ring obtains new FPS measurements.
    if ($ui.HomePage.Visibility -ne [Windows.Visibility]::Visible) { return }
    $elapsed = [math]::Max(0.001, [math]::Min(0.15, [double]$script:FpsFallbackDeltaSeconds))
    $target = [double]$script:FpsGaugeTargetValue
    $display = [double]$script:FpsGaugeVisualValue

    if (($target -gt 0.0 -or $script:FpsGaugeExiting) -and -not $script:FpsGaugeIsHeld) {
        $velocity = [double]$script:FpsGaugeVelocity
        # 0.17s critically damped motion: quicker than the long-lived hardware
        # bars, with continuous velocity when a fresh 250ms sample retargets it.
        $omega = 2.0 / 0.17
        $x = $omega * $elapsed
        $decay = 1.0 / (1.0 + $x + 0.48 * $x * $x + 0.235 * $x * $x * $x)
        $change = $display - $target
        $temp = ($velocity + $omega * $change) * $elapsed
        $nextVelocity = ($velocity - $omega * $temp) * $decay
        $next = $target + ($change + $temp) * $decay

        # No overshoot/oscillation when a game suddenly changes frame rate.
        if (($target - $display) * ($target - $next) -lt 0.0) {
            $next = $target
            $nextVelocity = 0.0
        }
        # Settle just once near the true target instead of oscillating around
        # the integer label or adding a constant artificial micro-animation.
        if ([math]::Abs($next - $target) -lt $(if ($script:FpsGaugeExiting) { 0.12 } else { 0.025 }) -and
            [math]::Abs($nextVelocity) -lt $(if ($script:FpsGaugeExiting) { 1.0 } else { 0.4 })) {
            $next = $target
            $nextVelocity = 0.0
        }
        $display = [math]::Max(0.0, [double]$next)
        $script:FpsGaugeVisualValue = $display
        $script:FpsGaugeVelocity = [double]$nextVelocity
    }
    if ($script:FpsGaugeExiting -and $display -le 0.0) {
        # Display-only exit ended. Never leave a visible 0 or stale stat value.
        Clear-FpsLiveReading
        return
    }
    # A real capture gap holds the last measured value without inventing FPS.
    # Only the display *between* genuine samples is interpolated.
    if ($display -gt 0.0 -or $script:FpsGaugeExiting) {
        $label = if ($script:FpsGaugeExiting) {
            if ($display -lt 1.0) { '' } else { '{0:0}' -f $display }
        } elseif ($display -lt 1.0) {
            '{0:0.0#}' -f $display
        } elseif ($display -lt 10.0) {
            '{0:0.0}' -f $display
        } else {
            '{0:0}' -f $display
        }
        if ($ui.FpsLive.Text -cne $label) { $ui.FpsLive.Text = $label }
    }
    Update-FpsRingProgress
}

# Only the FPS fallback needs a dispatcher tick.
$fpsFallbackTimer = $null
if ($null -eq $script:FpsFramePresenter) {
    $fpsFallbackTimer = New-Object Windows.Threading.DispatcherTimer
    $fpsFallbackTimer.Interval = [timespan]::FromMilliseconds(33)
    $fpsFallbackTimer.Add_Tick({
        $now = [datetime]::UtcNow
        $script:FpsFallbackDeltaSeconds = ($now - $script:LastFpsFallbackFrame).TotalSeconds
        $script:LastFpsFallbackFrame = $now
        Update-SmoothFpsGauge
    })
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [timespan]::FromMilliseconds(250)

$timer.Add_Tick({
    # No top-level window entrance/exit animation or motion pause.
    $ui.Clock.Text = Get-Date -Format 'HH:mm:ss'
    # Capture snapshots refresh at the background engine's ~250ms cadence.
    # The ring's WPF timeline renders intermediate visual positions independently.
    if (([datetime]::UtcNow - $script:Fps430LastRender).TotalMilliseconds -ge 240) {
        $script:Fps430LastRender = [datetime]::UtcNow
        Update-RealGameFps
        if (($FpsDiagnostics -or $FpsProbe) -and $null -ne $script:FpsFramePresenter) {
            Write-FpsUiDiagnostic
            # Diagnostic-only WPF rendering callback frequency, not game FPS.
            $hzNow = [datetime]::UtcNow
            if (($hzNow - $script:FpsVisualRateLogged).TotalSeconds -ge 8) {
                $script:FpsVisualRateLogged = $hzNow
                Write-HsStartupLog (('FPS_RENDER_SAMPLE: WPF_CallbackHz={0:0.0}; FPS_Target={1:0.0}; FPS_Displayed={2:0.0}; Renderer=LinearClock; WorstCallbackGapMs={3:0.0}' -f
                    [double]$script:FpsFramePresenter.RenderHz,
                    [double]$script:FpsFramePresenter.LatestTarget,
                    [double]$script:FpsFramePresenter.DisplayValue,
                    [double]$script:FpsFramePresenter.WorstRenderGapMs))
            }
        }
    }
    if ($null -ne $state.Pending -and $state.Pending.IsCompleted) {
        try {
            $r = $worker.EndInvoke($state.Pending)

            if (-not $r.Count -or $null -eq $r[-1].Timestamp) {
                throw 'No telemetry snapshot returned'
            }

            if ($worker.Streams.Error.Count) {
                throw 'A telemetry provider failed'
            }

            Show-Reading $r[-1]
        }
        catch {
            $ui.Connection.Text = '● DATA UNAVAILABLE / RETRYING'
            Show-NetworkReading $null
            $script:LastHealthResult=$null
            Reset-SystemHealth 'DATA UNAVAILABLE'
                }
        finally {
            $state.Pending = $null
        }
    }

    if (
        $null -eq $state.Pending -and
        ((Get-Date) - $state.Started).TotalMilliseconds -ge $script:Config.RefreshMs
    ) {
        Start-Reading
    }

    if (
        $state.LastGood -gt [datetime]::MinValue -and
        ((Get-Date) - $state.LastGood).TotalMilliseconds -gt
            [math]::Max(10000, 4 * $script:Config.RefreshMs)
    ) {
        $ui.Connection.Text = '● STALE DATA / WAITING FOR PROVIDERS'
        Show-NetworkReading $null
        $script:LastHealthResult=$null
        Reset-SystemHealth 'DATA UNAVAILABLE'
    }
})

$window.Add_Closing({
    # Close immediately; no window shrinking or delayed exit callback.
    $state.Closing = $true
    Stop-Fps433Engine
    if ($null -ne $script:FpsFramePresenter) { $script:FpsFramePresenter.Dispose() }
    $timer.Stop()
    if ($fpsFallbackTimer) { $fpsFallbackTimer.Stop() }
})

function Initialize-MeterGlow {
    # Retained tinted glows plus low-amplitude opacity pulse.
    $tints = @{
        Cpu  = [Windows.Media.Color]::FromRgb(106,200,255) # cool blue
        Gpu  = [Windows.Media.Color]::FromRgb(101,223,166) # emerald green
        Ram  = [Windows.Media.Color]::FromRgb(193,154,255) # amethyst violet
        Temp = [Windows.Media.Color]::FromRgb(255,178,117) # warm orange
    }

    foreach ($meter in @('Cpu','Gpu','Ram','Temp')) {
        try {
            $bar = $ui[$meter + 'Bars']
            [void]$bar.ApplyTemplate()
            $indicator = $bar.Template.FindName('PART_Indicator', $bar)
            if ($null -eq $indicator) { continue }

            $halo = New-Object Windows.Media.Effects.DropShadowEffect
            $halo.Color = $tints[$meter]
            $halo.BlurRadius = 14
            $halo.ShadowDepth = 0
            $halo.Opacity = 0.85
            $indicator.Effect = $halo

            # Constant gentle shimmer without generating fake usage readings.
            $pulse = New-Object Windows.Media.Animation.DoubleAnimation
            $pulse.From = 0.83
            $pulse.To = 1.0
            $pulse.Duration = [Windows.Duration]::new([timespan]::FromMilliseconds(1700))
            $pulse.AutoReverse = $true
            $pulse.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
            $indicator.BeginAnimation([Windows.UIElement]::OpacityProperty, $pulse)
        }
        catch {
            # The template still provides its default silver-blue glow.
        }
    }
}

$window.Add_ContentRendered({
    if ($script:UiInitialized) { return }
    Initialize-CardShadows

    # OS owns the real HWND's first appearance. Initialize genuine telemetry
    # once after the first content paint.
    $script:UiInitialized = $true
    try {
        Start-Reading
        Start-Fps433Engine
        Update-RealGameFps
        Update-FpsRingProgress
        if (-not $script:MeterGlowInitialized) {
            Initialize-MeterGlow
            $script:MeterGlowInitialized = $true
        }
    }
    catch {
        Write-HsStartupLog ('STARTUP_RUNTIME_INIT_FAILED: ' + ($_ | Out-String))
    }
    finally {
        # Dashboard timers are not used to move or animate the HWND.
        $script:LastFpsFallbackFrame = [datetime]::UtcNow
        $timer.Start()
        if ($fpsFallbackTimer -and $window.WindowState -eq [Windows.WindowState]::Normal) {
            $fpsFallbackTimer.Start()
        }
        if ($null -ne $script:FpsFramePresenter) {
            $script:FpsFramePresenter.SetVisible([bool](
                $ui.HomePage.Visibility -eq [Windows.Visibility]::Visible -and
                $window.WindowState -eq [Windows.WindowState]::Normal))
        }
    }
})

try {
    [void]$window.ShowDialog()
}
finally {
    $state.Closing = $true
    
    Stop-Fps433Engine
    if ($null -ne $script:FpsFramePresenter) { $script:FpsFramePresenter.Dispose() }
    $timer.Stop()
    if ($fpsFallbackTimer) { $fpsFallbackTimer.Stop() }

    if ($null -ne $state.Pending) {
        try { $worker.Stop() } finally {
            try { [void]$worker.EndInvoke($state.Pending) } catch {}
            $state.Pending=$null
        }
    }

    $worker.Dispose()
    $runspace.Close()
    $runspace.Dispose()
}