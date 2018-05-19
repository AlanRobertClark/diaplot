function theDate = chooseDate(varargin)
  % chooseDate() centres calendar chooser around todays's date.
  % chooseDate(theDate) centres calendar chooser around theDate, which is a
  % number given by datenum(). chooseDate('click') is a callback
  % from a click to choose the date, or change month or year.
 
  % Asynchronous programming, so this function has to be re-entrant in
  % nature.  Hence, construct, but do not ever return until the final date
  % has been agreed upon :-) We do this by putting an item in the appdata,
  % whose altered presence we waitfor() before returning the chosen date
  % and self-annhilating.

  if ((nargin == 1) && (varargin{1}=='click'))
    % Its a CallBack, bypass Creation :-)
    click();
    return;

  % Create GUI...  
  elseif ((nargin == 1) && isfloat(varargin{1}))
    theDate = varargin{1};
  elseif nargin == 0
    theDate = floor(now);
  endif
  
  % Put it in the middle of the screen.
  calSize = [200, 200];
  screenSize = get(0, 'ScreenSize');
  calOrg = screenSize(3:4)./2 - calSize./2;
  bgColor = get(0, 'defaultUicontrolBackgroundColor');
  CFh = figure(...
    'Position', [calOrg, calSize],...
    'NumberTitle', 'Off',...
    'MenuBar', 'None',...
    'Name', 'Choose Date',...
    'Color', bgColor,...
    'WindowButtonDownFcn', 'chooseDate(''click'');'...
  );
  ud.theDate = theDate;
  [ud.theYear, ud.theMonth, ud.theDay] = datevec(theDate);
  ud.axes = [];
  set (CFh, 'UserData', ud);
  
  update(CFh);
  %%%%%%%%%%%%%%%%%%%%%%%%%
  % Asynchronous:
  % Do not return until the appdata is reset with the final date. This
  % happens once :-) Octave has a bug whereby the waitfor() interferes with
  % the screen updating due to creation, month/year clicking. A single
  % drawnow() clears the buffer, and thereafter everything is smooth. 
  %
  % FIXME: Octave uses __appdata__ to store Application Data. This is not
  % portable. Can't use UserData as a watch, since I store everything there
  % :-)
  setappdata (CFh, 'finalDate', 0);
  drawnow();
  waitfor (CFh, '__appdata__');
  theDate = getappdata (CFh, 'finalDate');
  delete(CFh);
endfunction

function click()
  % Called when the user clicks anywhere with the calendar. If on a date
  % number, the date is chosen. If on an arrow, the month/year is changed,
  % and the calendar updated. If anywhere else, nothing happens :-)
  % Remember that it is a 9 by 7 grid (18 by 14 at midpoints...)
  CFh = get(0, 'CurrentFigure');
  CBh = get(0, 'CallBackObject');
  ud = get (CFh, 'UserData');

  % This gets the 9 by 7 ``block''
  currentPnt = get(ud.axes, 'CurrentPoint');
  currentPnt = currentPnt(1, 1:2);
  xind = round((currentPnt(1)*14+1)/2);
  yind = round((currentPnt(2)*18+1)/2);

  dates = calendar(ud.theYear,ud.theMonth);

  % Is it in the 6 by 7 ``days'' section? Ignore if zero.
  if (xind >= 1) && (xind <= 7) && (yind >= 1) && (yind <= 6)
    theDay = dates(7-yind, xind);
    if theDay ~= 0 % Finished: Choose the new date...
      ud.theDay = theDay;
      ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
      % Return the value, and trigger the waitfor() ... 
      setappdata (CFh, 'finalDate', ud.theDate);
    endif
  elseif xind == 2 && yind == 9     % Decrease month
    if ud.theMonth == 1 % 31 days :-)
      ud.theYear -= 1; 
      ud.theMonth = 12;
      ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
      set(CFh, 'UserData', ud);
      update(CFh);
    else % Any other month than Jan.
      % If theDay > max days in new month, make it the last day.
      ud.theMonth -= 1;
      maxDay = eomday(ud.theYear, ud.theMonth);
      if ud.theDay > maxDay
        ud.theDay = maxDay;
      endif
      ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
      set(CFh, 'UserData', ud);
      update(CFh);
    endif
  elseif xind == 6 && yind == 9     % Increase month
    if ud.theMonth == 12 % Also 31 days :-)
      ud.theYear += 1;
      ud.theMonth = 1;
      ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
      set(CFh, 'UserData', ud);
      update(CFh);
    else % Any other month than December
      % If theDay > max days in new month, make it the last day.
      ud.theMonth += 1;
      maxDay = eomday(ud.theYear, ud.theMonth);
      if ud.theDay > maxDay
        ud.theDay = maxDay;
      endif
      ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
      set(CFh, 'UserData', ud);
      update(CFh);
    end
  elseif xind == 3 && yind == 8     % Decrease year
    ud.theYear -= 1;
    % If theDay > max days in new month, make it the last day.(leap)
    maxDay = eomday(ud.theYear, ud.theMonth);
    if ud.theDay > maxDay
      ud.theDay = maxDay;
    endif
    ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
    set(CFh, 'UserData', ud);
    update(CFh);
  elseif xind == 5 && yind == 8     % Increase year
    ud.theYear += 1;
    % If theDay > max days in new month, make it the last day.(leap)
    maxDay = eomday(ud.theYear, ud.theMonth);
    if ud.theDay > maxDay
      ud.theDay = maxDay;
    endif
    ud.theDate = datenum(ud.theYear, ud.theMonth, ud.theDay);
    set(CFh, 'UserData', ud);
    update(CFh);
  endif
endfunction

function update(CFh)
  % Fills the axes with the calendar information
  % This is a matrix 9 high by 7 wide. Since text is positioned by centre
  % alignment, it is useful to think of this as 18 high by 14 wide. Actual
  % month numbers takes up 6 by 7 (12 by 14). 
  % Remember that y increases upwards....
  ud = get(CFh, 'UserData');

  % Clear the entire previous axes
  if ~isempty(ud.axes)
    delete(ud.axes);
  endif
  ud.axes = axes('Position', [0, 0, 1, 1]); % Unit size....
  bgColor = get(0, 'defaultUicontrolBackgroundColor');
  Months = {'January', 'February', 'March',...
    'April', 'May', 'June',...
    'July', 'August', 'September',...
    'October', 'November', 'December'...
  };
  days = calendar(ud.theYear, ud.theMonth);
  % text and line objects go into current axes, of unit size... text
  % objects are 10 points, and aligned vertically in the middle.
  text(0.5, 17/18, Months{ud.theMonth}, 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold');
  % Display the year
  text(0.5, 15/18, num2str(ud.theYear), 'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold');
  % Display the days names
  dayNames = {'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'};
  for i = 1:7
    text((2*i-1)/14, 13/18, dayNames{i}, 'HorizontalAlignment', 'center', ...
      'FontWeight', 'bold');
  endfor
  line([0,1], [12.3/18,12.3/18], 'Color', [0,0,0], 'LineWidth', 0.8);
  % Display the dates and place a patch around the current date
  % The idea, basically, is that the ``current day'' is highlighted. Any
  % clicking on another month/year will change that concept. 
  for i = 1:6
    for j = 1:7
      if days(7-i,j) ~= 0
        if days(7-i,j) == ud.theDay
          patch([2*j-2;2*j;2*j;2*j-2]/14,...
            [2*i-2;2*i-2;2*i;2*i]/18, bgColor-[0.1,0.1,0.1],...
            'EdgeColor', bgColor-[0.1,0.1,0.1]);
          line([2*j-2;2*j;2*j]/14, [2*i-2;2*i-2;2*i]/18, 'Color',[0.9,0.9,0.9]);
          line([2*j;2*j-2;2*j-2]/14, [2*i;2*i;2*i-2]/18, 'Color',[0,0,0])
        endif
        text((2*j-1)/14, (2*i-1)/18, num2str(days(7-i,j)),...
          'HorizontalAlignment', 'center'...
          );
      endif
    endfor
  endfor
  
  % Serious magic for arrow vertices :-)
  rightArrow = [0,0.3; 0.5,0.3; 0.5,0; 1,0.5; 0.5,1; 0.5,0.7; 0,0.7];
  leftArrow = [0,0.5; 0.5,0; 0.5,0.3; 1,0.3; 1,0.7; 0.5,0.7; 0.5,1];
  upArrow = [0,0.5; 0.5,1; 1,0.5; 0.7,0.5; 0.7,0; 0.3,0; 0.3,0.5];
  downArrow = [0,0.5; 0.3,0.5; 0.3,1; 0.7,1; 0.7,0.5; 1,0.5; 0.5,0];
  % Display the arrows to increase/decrease the month and year (black)
  patch(leftArrow(:,1)/21+3/14-0.5/21, leftArrow(:,2)/27+17/18-0.5/27,...
    [0,0,0]);
  patch(rightArrow(:,1)/21+11/14-0.5/21, rightArrow(:,2)/27+17/18-0.5/27,...
    [0,0,0]);
  patch(downArrow(:,1)/21+5/14-0.5/21, downArrow(:,2)/27+15/18-0.5/27,...
    [0,0,0]);
  patch(upArrow(:,1)/21+9/14-0.5/21, upArrow(:,2)/27+15/18-0.5/27,...
    [0,0,0]);
  axis([0 1 0 1]); % Re-square it up.
  set(CFh, 'UserData', ud);
endfunction
