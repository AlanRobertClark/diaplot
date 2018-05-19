function printEpsPng (name)
% Converts the current plot into an .eps file for printing and a .png file
% for web-browsing. It also labels the plot using the calling name, so that
% the files are easily locate()-able afterwards :-)
% It is called with a filename-without-extension, in typical fashion.
 
text(1, 0.02, name, 'Units', 'normalized', 'HorizontalAlignment', 'right')
print ([name,'.eps'], '-depsc', '-FTimes-Roman:12')
print ([name,'.png'], '-dpng', '-FTimes-Roman:12', '-r0')
% Above line produces really crappy png's. May be fixed later of course,
% for now, use my proprietory method :-) eps2png:
%system (['eps2png ',name]);
%text(); % Must use to clear labels (they are persistent for some reason!)
endfunction
