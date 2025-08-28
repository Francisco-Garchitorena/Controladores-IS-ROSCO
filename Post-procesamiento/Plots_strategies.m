%%
[Channels, ChanName, ChanUnit, FileID, DescStr] = ReadFASTbinary('../Test_Wang_OF/IEA-3.4-130-RWT_Wang_9.outb');

% Encontrar índice de la variable 'RotTorq'
idx = find(strcmp(ChanName, 'RotTorq'));
% Plot
figure; fontsize =14;
idx_trans = 30/0.00625;
plot(Channels(idx_trans:end, 1), Channels(idx_trans:end, idx), 'LineWidth', 1.5); hold on;
ylabel('Torque aerodinamico [Nm]', 'Interpreter', 'latex', 'FontSize', fontsize);
xlabel('Tiempo [s]', 'Interpreter', 'latex', 'FontSize', fontsize);
%legend('Real', 'Estimado', 'Interpreter', 'latex', 'FontSize', fontsize)
grid on;
title('Torque aerodinamico estimado vs real', 'Interpreter', 'latex', 'FontSize', fontsize);
xlim([30 200])
