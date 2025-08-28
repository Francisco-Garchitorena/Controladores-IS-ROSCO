function [ext, exttime] = sig2ext(sig, dt, clsn)
% SIG2EXT - searches local extrema from time course (signal),
% 
% function [ext, exttime] = sig2ext(sig, dt, clsn)
%
% SYNTAX
%   sig2ext(sig)
%   [ext]=sig2ext(sig)
%   [ext,exttime]=sig2ext(sig)
%   [ext,exttime]=sig2ext(sig, dt)
%   [ext,exttime]=sig2ext(sig, dt, clsn)
%
% OUTPUT
%   EXT     - found extrema from signal SIG,
%   EXTTIME - option, time of extremum occurrence counted from
%             sampling time of DT course (in seconds).
%             If no sampling time, DT = 1 is assumed.
%
% INPUT
%   SIG     - required, time course of loading,
%   DT      - option, descripion as above, scalar or vector of
%             the same length as SIG,
%   CLSN    - option, a number of classes of SIG (division before
%             search of extrema), no CLSN means no division into classes.
%
% The function caused without an output draws a course graph with
% the searched extrema.
%

%
% by Adam Nies³ony
%


% Sprawdza iloœæ parametrów na wejœciu
error(nargchk(1,3,nargin))

% Sprawdza czy analizowany jest te¿ czas
% TimeAnalize=(nargout==0)|(nargout==2);
% Ale:
TimeAnalize=( (nargout==0) || (nargout==2) );

% Sprawdzam czy przyrost dt jest podany prawid³owo
if nargin==1,
    dt=1;
else
    dt=dt(:);
end

% Zamieniam dane sig na jedn¹ kolumnê
sig=sig(:);

% Dzielimy na klasy je¿eli jest podane CLSN
if nargin==3,
    if nargout==0,
        oldsig=sig;
    end
    clsn=round(clsn)-1;
    smax=max(sig);
    smin=min(sig);
    sig=round((sig-smin).*clsn/(smax-smin)).*(smax-smin)/clsn + smin;
end

% Tworzê wektor binarny w gdzie 1 oznacza ekstremum lub równoœæ,
% Uznajê ¿e pierwszy i ostatni punkt to ekstremum
w1=diff(sig);
w=logical([1;(w1(1:end-1).*w1(2:end))<=0;1]);
ext=sig(w);
if TimeAnalize,
    if length(dt)==1,
        exttime=(find(w==1)-1).*dt;
    else
        exttime=dt(w);
    end
end

% Usuwam potrójne wartoœci
w1=diff(ext);
w=~logical([0; w1(1:end-1)==0 & w1(2:end)==0; 0]);
ext=ext(w);
if TimeAnalize,
    exttime=exttime(w);
end

% Usuwam podwójne wartoœci i przesuwam czas na œrodek
w=~logical([0; ext(1:end-1)==ext(2:end)]);
ext=ext(w);
if TimeAnalize,
    w1=(exttime(2:end)-exttime(1:end-1))./2;
    exttime=[exttime(1:end-1)+w1.*~w(2:end); exttime(end)];
    exttime=exttime(w);
end

% Jeszcze raz sprawdzam ekstrema
if length(ext)>2,  % warunek: w tym momencie mo¿e ju¿ byæ ma³o punktów
    w1=diff(ext);
    w=logical([1; w1(1:end-1).*w1(2:end)<0; 1]);
    ext=ext(w);
    if TimeAnalize,
        exttime=exttime(w);
    end
end

if nargout==0,
    if length(dt)==1,
        dt=(0:length(sig)-1).*dt;
    end
    if nargin==3,
        plot(dt,oldsig,'b-',dt,sig,'g-',exttime,ext,'ro')
        legend('SIGNAL','SIGNAL + CLS','EXTREMA')
    else
        plot(dt,sig,'b-',exttime,ext,'ro')
        legend('SIGNAL','EXTREMA')        
    end
    xlabel('time')
    ylabel('signal & extrema')
    clear ext exttime
end

