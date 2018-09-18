
xlim(gca,[1 ,4])
ylim(gca,[0 ,1])
set(gca,'xticklabel',{'','left' ,'right',''},'XTick',[1 2 3 4]) %makes left and right label on xaxis
set(gca,'ytick',1) %makes the yaxis only have number 1
hold on

plot([1 2 3],[0.5 4 6],'o');