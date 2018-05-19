% diaplot.m
%
% diaplot("fn.txt")
% diaplot()
% 
% GUI is created with a CallBack event-driven interface, handled via a
% SwitchYard, all through this single file.
%
% External requirements are chooseDate, printEpsPng, and arcmakemenu.
%
% diaplot() reads files, entries starting the line with a valid
% Date-and-time stamp: 2018/05/14 08h34 followed by a Blood Glucose reading
% in mmol/l, a bolus injection, a basal injection(suffixed with L for
% Lantus), or any combination of the above! Comments on meals etc follow.
% Any line not following the above is ignored.
%
% Plots are Blood Glucose versus time, a daily mean and standard deviation
% quadrant plot (High/low vs Stable/Unstable), Insulin versus time,
% Total Daily Dose (bolus, just add the basal :-) versus time, and a Blood
% Glucose versus time-of-day (line per day).
%
% The mean/std.dev. dot-per-day and BG vs time-of-day. line per day are
% clickable, and the actual date corresponding to the dot/line appears in
% the plot title.
%
% The plots are saveable (just give the filname, without extension, and an
% .eps and .png version is saved for printing and web-viewing) and the date
% range is settable within the data that is loaded. 
%
% Data files are concatenated, so many can be read in sequence. (They are
% not subsequently sorted :-)
%
% 20180514 AlanRobertClark@gmail.com


function diaplot(fname);
% -------------------------------------------------------------------------
% If called with a filename, do a default read and BG plot, creating the
% gui. No filename: a) if the gui does not exist, create. b) if gui exists,
% and not a valid CallBack, return.  Otherwise, handle the legitimate
% CallBack in the Switchyard.
% -------------------------------------------------------------------------

  CFh = get(0, 'CurrentFigure');
  CBh = get(0, 'CallBackObject');
  
  if isempty(CFh)
    CFh = diaplotCreate();
    if ((nargin == 1) && ischar(fname))
      Dfid = fopen(fname, 'rt');
      if Dfid == '-1'
        errordlg(['File: ' fname ' could not be opened.']);
      endif
      diaplotFileOpenAppendData(CFh, Dfid);
      return;
    endif;
  endif
  
  if isempty(CBh)
    return;
  endif;
  
  % Figure exists with a CallBack:
  CBTag = lower(get(CBh, 'Tag'));
  
  % Actual SwitchYard...
  switch CBTag
  case 'file.open...'
    diaplotFileOpenAppendDataGui(CFh);
  case 'file.save_plot...'
    diaplotFileSavePlot(CFh);
  case 'file.exit'
    btn=questdlg('Close diaplot()?','Close Application',...
      '&Yes','&No','&No');
    if strcmpi(btn, '&Yes')
      close(CFh);
    endif
  case 'date_range.start_date'
    % Cannot do this at higher level... Wrong ud gets overwritten.
    ud = get(CFh, 'UserData');
    ud.startDate = chooseDate(ud.startDate);
    set (CFh, 'UserData', ud);
    diaplotUpdate(CFh);
  case 'date_range.end_date'
    ud = get(CFh, 'UserData');
    ud.endDate = chooseDate(ud.endDate);
    set (CFh, 'UserData', ud);
    diaplotUpdate(CFh);
  % plot type simply checks the right uimenu box....
  case {'plot_type.glucose_time', 'plot_type.quadrant_scatter',...
        'plot_type.insulin_time', 'plot_type.tdd_time',...
        'plot_type.glucose_hour'}
    % Clear all previous checks.
    pa = get(CBh, 'parent');
    chld = get(pa, 'children');
    set(chld, 'Checked', 'Off');
    set(CBh, 'Checked', 'On');
    diaplotUpdate(CFh);
  case 'dayline'
    % User clicked on a line in the BG Hourly plot.
    allLines = findobj(CFh, 'Tag', 'dayline');
    set(allLines, 'color', 'black');
    set(CBh, 'color', 'green');
    linedate = get(CBh, 'UserData');
    title (['Blood Glucose Hourly ' datestr(linedate, 'yyyymmdd')]);
  case 'meandevdot'
    % User clicked on a dot in the BG mean vs. standard deviation
    allLines = findobj(CFh, 'Tag', 'meandevdot');
    set(allLines, 'markerfacecolor', 'white');
    col = get(CBh, 'color');    
    set(CBh, 'markerfacecolor', col);
    linedate = get(CBh, 'UserData');
    title (['Daily mean vs. standard deviation ',...
      datestr(linedate, 'yyyymmdd')]);
    
    
  case 'help.about'
    helpdlg(...
    {'Diabetes Plotter, diaplot()',...
    'Version 1.0','',...
    'Plots graphs of Blood Glucose levels,',...
    'Insulin intake, versus time, as well as',...
    'various statistical data to assist BG control',...
    '', 'AlanRobertClark@gmail.com 20180309'}...
    , 'About diaplot()');
  endswitch ;
endfunction

function valid = validDTS(str)
% -------------------------------------------------------------------------
% returns true if a valid date and time stamp is in the string. dts in
% vim() returns a standard format: 2016/02/07 00h54 . All other lines do
% not contain valid data, and are simply ignored. (7th Feb :-)
% vimrc: iab <expr> dts strftime("%Y/%m/%d %Hh%M")
% -------------------------------------------------------------------------
  valid = false;
  if numel(str) >= 16
    if ((str(5)=='/')&&(str(8)=='/')&&(str(14)='h'))
      valid = true;
    endif
  endif
endfunction


function diaplotFileOpenAppendDataGui(CFh)
% -------------------------------------------------------------------------
% Calls the GUI to set the file name and then do the call to read...
% -------------------------------------------------------------------------
  [Dfn, Dpn, Didx] = uigetfile ('D.txt', 'Diaplot Data File');
  Dfqn = fullfile (Dpn, Dfn);
  Dfid = fopen (Dfqn, 'rt');
  if Dfid == '-1'
    errordlg (['File: ' Dfqn ' could not be opened.']);
    % No point in continuing :-)
    return
  endif
  diaplotFileOpenAppendData(CFh, Dfid);
endfunction

function diaplotFileOpenAppendData(CFh, Dfid)
% -------------------------------------------------------------------------
% Reads the file, and *appends* the data to the UserData structure in the
% order read. Dfid is already checked as valid. Read ALL valid data into
% Data Structure. Store Start and End dates, and separate arrays of BG,
% bolus and basal.
% -------------------------------------------------------------------------
  ud = get (CFh, 'UserData');
  while (!feof(Dfid))
    textl = fgetl (Dfid);
    if validDTS(textl)
      % extract data...
      when = datenum (textl(1:16),'yyyy/mm/dd HHhMM');
      
      if numel(textl) >= 28
        numbers = textl(17:28);
      else
        numbers = textl(17:end);
      endif
      % Add some padding, regardless :-)
      numbers = [numbers, '   '];

      % ``numbers'' now contains some free-ish form data: By convention
      % this is either BG `10.3' or BG bolus `10.3  8' or BG basal,bolus
      % `10.3 24L,8' or BG basal '10.3 24L' or bolus `8' or basal `24L' or
      % basal,bolus `24L,8'.  Simple, Really :-)
      %
      % First, is there a BG?, then both then basal or bolus. Note we
      % remove what we have already dealt with...  Also need to deal with
      % empty sscanf results..... (including false L's in comments, without
      % numbers :-)
      BGexist = index(numbers, '.');
      if BGexist > 0
        BG = sscanf(numbers(BGexist-2:BGexist+1), '%f', 'C');
        numbers(BGexist-2:BGexist+1)=' ';
        if ~isempty(BG)
          ud.BG(end+1,1) = when;
          ud.BG(end,2) = BG;
        endif
      endif
      both = index(numbers, 'L,');
      if both > 0
        [basal,bolus] = sscanf(numbers(both-2:both+3),'%dL,%d', 'C');
        numbers(both-2:both+3) = ' ';
        if ~isempty(basal)
          ud.basal(end+1,1) = when;
          ud.basal(end,2) = basal;
        endif
        if ~isempty(bolus)
          ud.bolus(end+1,1) = when;
          ud.bolus(end,2) = bolus;
        endif
      endif
      basEx = index(numbers,'L');
      if basEx > 0
        basal = sscanf(numbers(basEx-2:basEx), '%dL', 'C');
        numbers(basEx-2:basEx) = ' ';
        if ~isempty(basal)
          ud.basal(end+1,1) = when;
          ud.basal(end,2) = basal;
        endif
      endif
      bolus = sscanf(numbers, '%d','C');
      if ~isempty(bolus)
        ud.bolus(end+1,1) = when;
        ud.bolus(end,2) = bolus;
      endif
    endif
  endwhile
  % Allow menu functions to execute.
  set(ud.handles.stored.plot_type, 'Enable', 'On');
  set(ud.handles.stored.date_range, 'Enable', 'On');
  % basal should be the most consistent data...
  ud.startDate = floor(ud.basal(1,1));
  ud.endDate = floor(ud.basal(end,1));

  set(CFh, 'UserData',ud);
  % Re-draw... (or for the first time...)
  diaplotUpdate(CFh);
endfunction

function CFh = diaplotCreate()
% -------------------------------------------------------------------------
% Actually does the GUI creation...
% -------------------------------------------------------------------------
  
  CFh = figure('Name', 'Diabetes Plotter', ...
               'NumberTitle', 'Off');%, ...
%               'MenuBar', 'None');%,... %Octave Bug 53307!
%               'ToolBar', 'None');
%  set(CFh,'MenuBar', 'None');
  ud = get(CFh, 'UserData');
  % Store the position before the bug changes it. Use figreset().
  ud.dataAx = axes;
  ud.pos = get(CFh, 'Position');
  set(CFh, 'CurrentAxes', ud.dataAx);
  
  menu = {'&File', '>&Open...', '>&Save_Plot...^s', '>--', '>E&xit^q'};
  ud.handles.menu = arcmakemenu(CFh, 'diaplot;', menu);
  
  menu = {'&Date_Range', '>&Start_Date', '>&End_Date'};
  handles = arcmakemenu(CFh, 'diaplot;', menu);
  ud.handles.menu = [ud.handles.menu, handles];
  ud.handles.stored.date_range = handles(1);
  set(ud.handles.stored.date_range, 'Enable', 'Off'); % until File.Open...
  
  menu = {'&Plot_Type', '>&Glucose_Time', '>&Quadrant_Scatter', ...
  '>&Insulin_Time', '>&TDD_Time', '>Glucose_&Hour'};
  handles = arcmakemenu(CFh, 'diaplot;', menu);
  ud.handles.menu = [ud.handles.menu, handles];
  ud.handles.stored.plot_type = handles(1);
  ud.handles.stored.plot_types = handles(2:end); %Careful naming!!!!
  set(ud.handles.stored.plot_type, 'Enable', 'Off'); % until File.Open...
  set(ud.handles.stored.plot_types, 'Checked', 'Off');
  set(ud.handles.stored.plot_types(1), 'Checked', 'On'); % Default BG-time.
  set(CFh, 'UserData', ud);
  
  % I haven't figured out WHY, but this must come AFTER the uimenu items
  % have been added ???????? Turning off the menu, then adding uimenu items
  % to CFh does NOT reactivate the menu bar. It always has before. Reported
  % as Octave Bug 53307.
  set(CFh,'MenuBar', 'None');
  
  % Try afterwards.... (Works too!)
  menu = {'&Help','>&About'};
  handles = arcmakemenu(CFh, 'diaplot;', menu);
  ud.handles.menu = [ud.handles.menu, handles];
  set(CFh, 'UserData', ud);
  % Try reset the growth bug Bug Report 53775.
  % set(CFh, 'Position', ud.pos);
endfunction


function diaplotFileSavePlot(CFh)
% -------------------------------------------------------------------------
% Print the currentplot without the GUI bits...
% -------------------------------------------------------------------------
  [fname, fpath, fltidx] = uiputfile('filename',...
    'Saves current plot as filename.eps and filename.png');
  printEpsPng(fname);
endfunction


function diaplotUpdate(CFh)
% -------------------------------------------------------------------------
% From startDate to endDate, plot the required data for the particular
% plot type
% -------------------------------------------------------------------------

  % Some Constants I might want to change at some point...
  BG.low = 3.5;
  BG.high = 20.0;
  Mn.min = 4;
  Mn.mid = 8;
  Mn.max = 15;
  SD.min = 0;
  SD.mid = 3; % 2.5? Should be 1/3 of mean.
  SD.max = 8;

  ud = get(CFh, 'UserData');
  plotType = ud.handles.stored.plot_types;
  chk = findobj(plotType, 'Checked', 'On');
  indx = (plotType(:)==chk);

  % Pseudo Switch. :-)
  % case 'glucoseTime'
  if indx(1)
    % >= and <+1 : midnight to midnight.....
    subset = (ud.BG(:,1) >= ud.startDate & ud.BG(:,1) < ud.endDate + 1);
    plotData = [ud.BG(subset,1), ud.BG(subset,2)];

    % Qt single precision Bug 53832.
    % Epoch is 1 Jan 0 A.D. 737190 days ago, and we are plotting
    % time-of-day, ie fractions. Qt (OpenGL) is 32-bit single precision, so
    % the fractions get ``lost'', and plot errors are large. Remove the
    % large offset, plot fractional data, and add the days back before
    % labelling :-)
    offset = floor(plotData(1,1)); 

    % find lows and highs...only with in the plottable data though....
    lowhiset = ((plotData(:,2) <= BG.low) | (plotData(:,2) >= BG.high));
    lowhidata = [plotData(lowhiset,1), plotData(lowhiset,2)];

    plot(ud.dataAx, plotData(:,1) - offset, plotData(:,2),'-',...
      lowhidata(:,1) - offset, lowhidata(:,2), 'o', 'markerfacecolor', 'red');
    axlim = axis;
    BGmean = mean(ud.BG(subset,2));
    BGstd  = std(ud.BG(subset,2));
    dataStr = sprintf ('(%d days); mn = %0.1f; \\sigma = %0.1f',...
      ud.endDate - ud.startDate + 1, BGmean, BGstd);
    text(axlim(1) + 0.5*(axlim(2) - axlim(1)),...
      axlim(3) + 0.05*(axlim(4) - axlim(3)), dataStr,...
      'HorizontalAlignment', 'center');
    xticklabels = get(ud.dataAx, 'xticklabel');
    for i = 1:numel(xticklabels)
      j = str2double(xticklabels{i}) + offset;
      xticklabels{i} = datestr(j, 'yyyymmdd');
    endfor;
    set(ud.dataAx, 'xticklabel', xticklabels);
    grid on;
    ylabel('Blood Glucose (mmol/l)');
    title('Blood Glucose---Time');
  endif
  % case 'quadrantScatter'
  if indx(2)
    subset = (ud.BG(:,1) >= ud.startDate & ud.BG(:,1) <= ud.endDate + 1);
    % Need day, Mn, SD for individually clickable dots....
    plotData = [ud.BG(subset,1),ud.BG(subset,2),ud.BG(subset,1)];
    % for each day, calculate the Mean and Std Dev. Remove hours.
    plotData(:,1) = floor(plotData(:,1));
    totalMean = mean(plotData(:,2));
    totalStd  = std(plotData(:,2));
    i=1;
    while(i <= numel(plotData(:,1)))
      % Count how many on same day
      today = plotData(i,1);
      j=1;
      while ((i+j <= numel(plotData(:,1))) && (plotData(i+j,1) == today))
        j++;
      endwhile
      j--; % One too many (while)
      select = [plotData(i:i+j,2)];
      dev = std(select);
      mn = mean(select);
      plotData(i:i+j, 2) = mn;
      plotData(i:i+j, 3) = dev;
      i+=j; % next day......
      i++; % next loop :-)
    endwhile
    plotData = unique(plotData, 'rows');

    % Saturate data outside of axis() onto the edge of axis()
    subset = (plotData(:,2) > Mn.max);
    plotData(subset, 2) = Mn.max;
    subset = (plotData(:,3) > SD.max);
    plotData(subset, 3) = SD.max;
 
    % Establish axis etc...
    plot(ud.dataAx, plotData(:,3), plotData(:,2), 'Visible','Off');
    
    % Non(Green/Red) ought to be yellow, but can't bloody see it: hence
    % blue. Each dot is clickable, for the date.
    for i = 1:numel(plotData(:,1))
      col = 'blue';
      if ((plotData(i,3) <= SD.mid) && (plotData(i,2) <= Mn.mid))
        col = 'green';
      endif
      if ((plotData(i,3) > SD.mid) && (plotData(i,2) > Mn.mid))
        col = 'red';
      endif
      line (ud.dataAx, plotData(i,3), plotData(i,2), 'marker','o',...
        'color', col, 'Tag', 'meandevdot',... 
        'ButtonDownFcn', 'diaplot;',...
        'UserData', plotData(i,1));
    endfor
    title ('Daily mean vs. standard deviation');
    % Note %0.1f gives the one decimal, and however many digits before.
    dataStr = sprintf ('%s to %s (%d days); mn = %0.1f; \\sigma = %0.1f',...
      datestr(ud.startDate, 'yyyymmdd'), datestr(ud.endDate, 'yyyymmdd'),...
      ud.endDate - ud.startDate + 1, totalMean, totalStd);
    axis ([SD.min SD.max Mn.min Mn.max]);
    line(ud.dataAx, [SD.mid SD.mid], [Mn.min Mn.max]);
    line(ud.dataAx, [SD.min SD.max], [Mn.mid Mn.mid]);
    text((SD.max-SD.min)/2, Mn.min + 0.05*(Mn.max - Mn.min), dataStr,...
      'HorizontalAlignment','center');
    xlabel('\sigma (mmol/l)');
    ylabel('mean (mmol/l)');
    grid on;
  endif
  % case 'insulin_time'
  if indx(3)
    subset = (ud.basal(:,1) >= ud.startDate & 
              ud.basal(:,1) <= ud.endDate + 1);
    subset2 = (ud.bolus(:,1) >= ud.startDate &
               ud.bolus(:,1) <= ud.endDate + 1);
    totalBolus = sum(ud.bolus(subset2,2));
    offset = floor(ud.bolus(1,1));
    plot(ud.dataAx, 
      ud.basal(subset,1) - offset, ud.basal(subset,2), '-d;basal;',...
      ud.bolus(subset2,1) - offset, ud.bolus(subset2,2), '-o;bolus;');
    axislim = axis;
    xticklabels = get(ud.dataAx, 'xticklabel');
    for i = 1:numel(xticklabels)
      j = str2double(xticklabels{i}) + offset;
      xticklabels{i} = datestr(j, 'yyyymmdd');
    endfor;
    set(ud.dataAx, 'xticklabel', xticklabels);
    title('Insulin intake');
    ylabel('Insulin (IU) basal, bolus');
    dataStr = sprintf (['(%d days); Bolus: mn = %0.1f;',...
      ' \\sigma = %0.1f; \\Sigma = %d (%0.1f pens)'],
      ud.endDate - ud.startDate + 1, mean(ud.bolus(subset2,2)),
      std(ud.bolus(subset2,2)), totalBolus, totalBolus/300);
    text(axislim(1) + (axislim(2) - axislim(1))/2, 
      axislim(3) + 0.05*(axislim(4) - axislim(3)), dataStr,...
      'HorizontalAlignment', 'center');
    grid on;
  endif
  % case 'TotalDailyDose_time'
  if indx(4)
    % bolus is the important bit.......basal is constant.
    subset = (ud.bolus(:,1) >= ud.startDate & 
              ud.bolus(:,1) <= ud.endDate + 1);
    plotData = [ud.bolus(subset,1), ud.bolus(subset,2)];
    % Granularise the day... 
    plotData(:,1) = floor(plotData(:,1));
    offset = plotData(1,1);
    i=1;
    while(i <= numel(plotData(:,1)))
      % Count how many on same day
      today = plotData(i,1);
      j=1;
      while((i+j <= numel(plotData(:,1))) && (plotData(i+j,1) == today))
        j++;
      endwhile
      j--; % One too many (while)
      select = [plotData(i:i+j,2)];
      tdd = sum(select);
      plotData(i:i+j, 2) = tdd;
      i+=j; % next day......
      i++; % next loop :-)
    endwhile
    plotData = unique(plotData, 'rows');
    totalMean = mean(plotData(:,2));
    totalStd  = std(plotData(:,2));
    plot(ud.dataAx, plotData(:,1) - offset, plotData(:,2));
    axislim = axis;
    title('Total Daily Dose (Bolus)');
    ylabel('Bolus Insulin (IU)');
    xticklabels = get(ud.dataAx, 'xticklabel');
    for i = 1:numel(xticklabels)
      j = str2double(xticklabels{i}) + offset;
      xticklabels{i} = datestr(j, 'yyyymmdd');
    endfor;
    set(ud.dataAx, 'xticklabel', xticklabels);
    dataStr = sprintf ('(%d days); mn = %0.1f; \\sigma = %0.1f',...
      ud.endDate - ud.startDate + 1, totalMean, totalStd);
    text(axislim(1) + (axislim(2) - axislim(1))/2, 
      axislim(3) + 0.05*(axislim(4) - axislim(3)), dataStr,...
      'HorizontalAlignment', 'center');
    grid on;
  endif
  % case 'BG vs time-of-day'
  if indx(5)
    % >= and <+1 : midnight to midnight.....
    subset = (ud.BG(:,1) >= ud.startDate & ud.BG(:,1) < ud.endDate + 1);
    plotData = [ud.BG(subset,1), ud.BG(subset,2)];

    days = floor(plotData(:,1));

    plotData(:,1) = mod(plotData(:,1),1);
    % find lows and highs...only with in the plottable data though....
    lowhiset = ((plotData(:,2) <= BG.low) | (plotData(:,2) >= BG.high));
    lowhidata = [plotData(lowhiset,1), plotData(lowhiset,2)];

    % Reshape per-day, each having a different number of tests, each having
    % a seperate clickable line, revealing the date..... Establish axis
    % first, and red dots :-)
    plot(ud.dataAx, plotData(:,1), plotData(:,2), 'Visible','Off',...
      lowhidata(:,1), lowhidata(:,2), 'o', 'markerfacecolor', 'red');
    axis([0 1 0 30]);
    datetick ('x','HHhMM');
    i=1;
    while(i <= numel(plotData(:,1)))
      prev = plotData(i,1);
      j=1;
      while((i+j <= numel(plotData(:,1))) && (plotData(i+j,1) > prev))
        prev = plotData(i+j,1);
        j++;
      endwhile
      j--; % while
      line(ud.dataAx, plotData(i:i+j,1), plotData(i:i+j,2),...
        'ButtonDownFcn', 'diaplot;', 'Tag','dayline',...
        'UserData', days(i));
      i+=j;
      i++;
    endwhile;
    xlabel('Time of day');
    ylabel('Blood Glucose (mmol/l)');
    title('Blood Glucose Hourly');
    grid on;
  endif
endfunction

% -------------------------------------------------------------------------
% UserData Documentation.
%
% ud.dataAx     plot axes
% ud.startDate  plot starting date. (datenum)
% ud.endDate    plot ending date. (datenum)
% ud.handles.menu    handles to uimenu entries (raw, in order of creation)
% ud.handles.stored  named uimenu entries for Checking etc.
%                    .plot_type  
%                    .plot_types all sub-menu items(for bulk de-Checking)
%                    .date_range top level menu for Enabling.
%
% ud.BG         matrix with time and Glucose
% -------------------------------------------------------------------------

