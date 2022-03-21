time = linspace(0.05,2.1,42);
deviation = [3.26 1.37 1.31 1.22 0.98 1.05 0.81 0.87 0.73 0.72 0.66 0.66 0.61 0.62 0.59 0.59 0.59 0.58 0.62 0.61 0.62 0.62 0.61 0.62 0.59 0.61 0.58 0.59 0.55 0.59 0.56 0.57 0.55 0.56 0.57 0.56 0.58 0.58 0.59 0.56 0.58 0.58];

figure;
s1 = subplot(15, 1, 1:13);
plot(time,deviation,'b-o');

plotTitle = 'Deviation Per Time';
title(gca, plotTitle);
xlabel(gca, 'Simulation Time (sec)');
ylabel(gca, 'Deviation');
axis([0.05 2.1 0 4]);

grid on;
hold off;