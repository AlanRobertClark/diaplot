function [handles] = arcmakemenu(CFh, callback, labels);
% ARCMAKEMENU Make an automatic menu structure for a Switchyard.
% 
% Modelled after MAKEMENU, but tailored to an event-driven,
% Switchyard-styled single callback GUI, based on *automatically-generated*
% tag strings.
%
% It returns a vector of uimenu handles, which are generally stored by the
% calling program in ud.handles.menu, to enable easy searching for
% 'Enable'ing and 'Checked' 'On' facility. When a menu item is selected,
% the callback can be processed for the auto-generated 'Tag' via the CBh.
%
% The menu labels are passed as a cellarray of strings with special
% meanings: 
%   _ spaces in the desired label are underscores, 
%   > denotes the menu level, 
%   & is the keyboard (Alt) menu-shortcut (\& escapes), 
%   - is a separator bar (---- :-), and 
%   it may END with ^ for an overall (menu-less) accelerator (Ctrl),
%   label... (3dots) is the CONVENTION to indicate a DialogBox item.
%
% The auto-generated tagstrings are then the same as the labels, dot(.)
% separated, without the confetti, back with underscores not spaces. 
%
% Usage:
% 
% CFh = figure ; 
% menus = { ...  
%   '&File' ...
%   '>&Open' ...  
%   '>>&Data_file...' ...  
%   '>>Ou&tput_file...' ...  
%   '>&Compile\&Run^b' ...  
%   '>&Save^s' ...
%   '>----' ...  
%   '>E&xit^q' ...  
%   '&Edit' ...  
%   '>&Copy' ...  
%   '>&Paste' ...
%   '>-'} ; 
% ud.handles.menu = arcmakemenu(CFh, 'diaplot;', menus) ;
% 
% Auto-generated Tags would be (eg) File.CompileRun and
% File.Open.Output_file..., handles to the menu items will be stored in
% ud.handles.menu
%
% To process the checking, or disabling of various menu items, note that a
% findobj(ud.handles.menu,'Tag','File.Open') also returns hits to children
% tags, so that we get a vector of (identical) handles, which is not
% useful. MUST use the `flat' flag to prevent searching children, since ALL
% menu items have their own handle. (or search using CFh, but is slower!)
% Finally, note that findobj is case insensitive. tAg, fiLe.oPEN works!
%
% Better to simply:
%   h=findobj(CFh,'Tag','File.Open'); % SLOWER
%   h=findobj(ud.handles.menu,'flat','Tag','File.Open'); % PREFERRED
% to get all handles in a hierarchy:
% h=findobj(ud.handles.menu,'flat','-regexp','Tag','File.Open');
%   set (h, 'Enable','Off');
% which produces the desired effect.
%
% Switchyard usage is then simple. There is ONE callback, eg 'diaplot;', 
% 
%   CBTag = lower(get(CBh, 'Tag'));
%   
%   % Actual SwitchYard...
%   switch CBTag
%   case 'file.open...'
%     diaplotFileOpenAppendDataGui(CFh);
%   case 'file.save_plot...'
%     diaplotFileSavePlot(CFh);
%   case 'file.exit'
%     btn=questdlg('Close diaplot()?','Close Application',...
%       '&Yes','&No','&No');
%     if strcmpi(btn, '&Yes')
%       close(CFh);
%     endif
%   case 'date_range.start_date'
% etc. etc....  

% AlanRobertClark@gmail.com 3 May 2016.
% 20180213 ud.handles.menu roundabout finally stopped.

% Argument sanity.
  narginchk(3,3);
  if ~ishandle (CFh)
    error('Current Figure handle must be defined.');
  endif
  if ~ischar (callback)
    error('callback must be a single string.');
  endif
  if ~iscellstr (labels)
    error('menu labels must be a cellarray of strings');
  endif

  % rememberHandles keeps track of where in the tree we are adding to.
  rememberHandles = CFh;
  currentLevel = 0;
  separatorFlag = 0;
  handles = [];

  for k = 1:numel(labels)
    tagStr = char([]); % regenerate each iteration.
    
    labelStr = labels{k};
    loc = find(labelStr ~= '>');
    if (isempty(loc))
      error ('Labels must contain something other than ''>''');
    endif
    newLevel = loc(1) - 1;
    
    % Get rid of the > indents, keeping track of which handle has babies
    % (increase in level) as well as when those babies finish (decrease).
    labelStr = labelStr(loc(1):length(labelStr));
    if (newLevel > currentLevel)
      rememberHandles = [rememberHandles handles(length(handles))];
    elseif (newLevel < currentLevel)
      N = length(rememberHandles);
      rememberHandles(N-(currentLevel-newLevel)+1:N) = [];
    end
    currentLevel = newLevel;
    
    % Flag for next round :-) uimenu below is associated with separator
    % above.
    if (labelStr(1) == '-')
      separatorFlag = 1;
    else
      if (separatorFlag)
        separator = 'on';
        separatorFlag = 0;
      else
        separator = 'off';
      end

      % Insert real & in label if reqd.
      loc = findstr(labelStr, '\&');
      amp = '&';
      labelStr(loc) = amp(1,ones(1,length(loc)));
      
      % Find the accelerator key, if any, and trash.
      accChar = char([]);
      L = length(labelStr);
      if (L > 1)
        if (labelStr(L-1) == '^')
          accChar = labelStr(L);
          labelStr(L-1:L) = [];
        endif
      endif

      % Collect the accumulated Tag (dot.separated) string as we move in
      % the hierarchy.  Note that rememberHandles will only have valid
      % uimenu objects after (2:end).
      if (length(rememberHandles) > 1)
        for i = 2:length(rememberHandles)
          tagStr = [tagStr, get(rememberHandles(i),'label'),'.'];
        endfor
      endif
      
      tagStr = [tagStr,labelStr];
      
      % Deunderscore the displayed label, keeping the underscores in tags,
      % Deampersand tag, not Displayed label. Reunderscore spaces in tag,
      % obtained from label in retrieval above... 
      labelStr (labelStr == "_") = " ";
      tagStr(tagStr =="&") = "";
      tagStr(tagStr ==" ") = "_";
      
      % Finally, then, the Grand Call for each menuitem made....
      h = uimenu(rememberHandles(length(rememberHandles)), ...
        'Label', labelStr, 'Accelerator', accChar, 'Callback', callback, ...
        'Separator',separator, 'Tag', tagStr);
      
      handles = [handles , h];
    endif % labelStr separator
  endfor % k
endfunction
