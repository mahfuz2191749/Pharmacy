%|************************************************************************
%|Software Devlopment 
%|by Md Mahfuzur Rahman (Team Leader)
%|************************************************************************


clc
clear all

% Load input parameters
run('input_parameters.m');

curr_path=mfilename('fullpath');
% Choose location where the results shell be saved
save_file_loc = uigetdir(curr_path(1:length(curr_path)-11) ,'Select path to store output data');

%% Creating array of wavelengths
lambda=[lambda_min:lambda_step:lambda_max];

batch=0;
%%
for alpha=alpha_batch
    for theta=theta_batch
        
        % Loop for the batchparameter: Thickness of AR-coating
        if sum(cellfun('length',d_AR_batch))==size(d_AR_batch,2)
            loc_AR=1;
        else
            loc_AR=find(cellfun('length',d_AR_batch)>1,1);
        end
        for d_AR_loop=d_AR_batch{loc_AR}
            d_AR=d_AR_batch;
            d_AR{loc_AR}=d_AR_loop;
            
            % Loop for the batchparameter: Depth of pyramid
            if sum(cellfun('length',p_bot_batch))==size(p_bot_batch,2)
                loc_pyr=1;
            else
                loc_pyr=find(cellfun('length',p_bot_batch)>1,1);
            end
            for p_bot_loop=p_bot_batch{loc_pyr}
                p_bot=p_bot_batch;
                p_bot{loc_pyr}=p_bot_loop;
                
                % Loop for the batchparameter: Thickness of layers
                if sum(cellfun('length',d_layer_batch))==size(d_layer_batch,2)
                    loc_lay=1;
                else
                    loc_lay=find(cellfun('length',d_layer_batch)>1,1);
                end
                for d_layer_loop=d_layer_batch{loc_lay}
                    d_layer=d_layer_batch;
                    d_layer{loc_lay}=d_layer_loop;
                    
                    batch=batch+1;
                    
                    %% Creating folder for results
                    formatOut = 'yyyy_mm_dd_hh_MM';
                    folderName=[datestr(now,formatOut) '_gen_batch-' num2str(batch) '_angle-' num2str(theta)];
                    mkdir(save_file_loc,folderName)
                    Gen_folder=[save_file_loc '\' folderName];
                                       
                    %% FINGERS AND BUSBARS
                    Mbb=wbb/(wbb+pbb);
                    Mf=pbb*wf/((wbb+pbb)*(wf+pf));
                    Msi=pbb*pf/((wbb+pbb)*(wf+pf));
                    
                    grid.share={Mbb Mf};
                    
                    %% ERROR CHECKING
                    
                    if sum([p_bot{1:end}]>[d_layer{1:end}])>0
                        errordlg('Hight of geom. feature is higher then layer thickness!')                                % Fehlermeldung
                        return
                    end
                    
                    if isequal(layer_mat{Substrate_pos},Si)~=1
                        errordlg('The substrate needs to be silicon!')                                % Fehlermeldung
                        return
                    end
                    %% Creating Cell array including all geometry data
                    layer_data = struct('layer_position',num2cell([1:size(layer_mat,2)]),'AR_mat',AR_mat,'d_AR',d_AR,'layer_mat',layer_mat,'d_layer',d_layer,'p_bot',p_bot,'lambert',lambert);
                    
                    S=0;
                    for S_loop=1:size(layer_mat,2)
                        eval(['S=' S_geom{S_loop} '(' num2str(S_loop) ', S, w, layer_data, plotting_geom);']);
                        S_all{S_loop}=S;
                    end
                    
                    %% STARTING LOOP FOR EACH WAVELENGTH
                    for lambda_batch=[lambda_min:lambda_step:lambda_max] % Loop for every wavelength
                        
                        if lambda_batch<960
                            nr_of_rays=nr_of_rays_1;
                        else
                            nr_of_rays=nr_of_rays_2;
                        end
                        
                        %% Initializing ray matrix
                        I_top=init_rays(rdm_ray_dir,theta,alpha,nr_of_rays,w,lambda_batch,lambda_batch,lambda_step);%lambda_min,lambda_max,lambda_step);
                        I_bot=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[]);
                        R_int=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[]);
                        T_tot_struct=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[]);
                        error_tot_struct=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[],'layer',[],'nr_of_bounces',[]);
                        interrupt_tot_struct=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[],'layer',[]);
                        A_tot_struct=struct('nr',[],'wavelength',[],'layer_position',[],'abs_loc',[]);
                        
                        %% STARTING LOOP FOR EACH RAY
                        for j=1:100; % Loop for every ray
                            
                            
                            %% Layer loop:
                            for layer_pos=1:size(layer_mat,2) % Loop for every layer
                                
                                if j>1
                                    if layer_pos~=size(layer_mat,2)
                                        I_bot=eval(['T_top' num2str(layer_pos+1)]);
                                    else
                                        I_bot=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[]);
                                    end
                                end
                                
                                [T_top, T_bot, A, error, interrupt]=layer(batch,theta,j,w,layer_data,layer_pos,grid, S_all{layer_pos}, I_top, I_bot, plotting_rays,xth_ray);
                                I_top=T_bot;
                                
                                
                                if layer_pos==1
                                    % Reflection data
                                    if isempty(R_int(1).nr)==1
                                        R_int=T_top;
                                    elseif isempty(T_top(1).nr)==1
                                        R_int=R_int;
                                    else
                                        R_int=[R_int T_top];
                                    end
                                else
                                    eval(['T_top' num2str(layer_pos) '=T_top;'])
                                end
                                
                                if layer_pos==size(layer_mat,2)
                                    if isempty(T_tot_struct(1).nr)==1
                                        T_tot_struct=T_bot;
                                    elseif isempty(T_bot(1).nr)==1
                                        T_tot_struct=T_tot_struct;
                                    else
                                        T_tot_struct=[T_tot_struct T_bot];
                                    end
                                    
                                    I_top=struct('nr',[],'wavelength',[],'start_loc',[],'dir_vector',[],'ray_col',[]);
                                end
                                
                                % Absorption data
                                if isempty(A_tot_struct(1).nr)==1
                                    A_tot_struct=A;
                                elseif isempty(A(1).nr)==1
                                    A_tot_struct=A_tot_struct;
                                else
                                    A_tot_struct=[A_tot_struct A];
                                end
                                
                                
                                %% Inserting errors from layer function in error_tot_struct
                                if isempty(error(1).nr)~=1&&isempty(error_tot_struct(1).nr)==1
                                    error_tot_struct=error;
                                elseif isempty(error(1).nr)~=1&&isempty(error_tot_struct(1).nr)~=1
                                    error_tot_struct=[error_tot_struct error];
                                end
                                
                                %% Inserting interrupts from layer function in interrupt_tot_struct
                                if isempty(interrupt(1).nr)~=1&&isempty(interrupt_tot_struct(1).nr)==1
                                    interrupt_tot_struct=interrupt;
                                elseif isempty(interrupt(1).nr)~=1&&isempty(interrupt_tot_struct(1).nr)~=1
                                    interrupt_tot_struct=[interrupt_tot_struct interrupt];
                                end
                                
                                %% The detector function is calculating the angles of incidence
                                if detect_bot(layer_pos)==1&&j==1
                                    angle_stats_bot_1=detector(T_bot);
                                    
                                end
                                if detect_top(layer_pos)==1&&j==1;
                                    angle_stats_bot_2=detector(T_top);
                                    
                                end
                            end
                            
                        end
                        
                        %% ********* PROCESSING RESULTS PER WAVELENGTH ***********
                        row=(lambda_batch-lambda_min)/lambda_step+1;
                        R_tot(row,1:2)=[lambda_batch length([R_int.wavelength])/nr_of_rays];
                        
                        A_fi(row,1:2)=[lambda_batch length([A_tot_struct([A_tot_struct.layer_position]==-1).wavelength])/nr_of_rays];
                        A_bb(row,1:2)=[lambda_batch length([A_tot_struct([A_tot_struct.layer_position]==-2).wavelength])/nr_of_rays];
                        A_AR(row,1:2)=[lambda_batch length([A_tot_struct([A_tot_struct.layer_position]==0).wavelength])/nr_of_rays];
                        
                        A_all_layers(row,1:2)=[lambda_batch 0];
                        for abs_layer=1:size(layer_mat,2)
                            eval(['A_' num2str(abs_layer) '(row,1:2)=[lambda_batch length([A_tot_struct([A_tot_struct.layer_position]==' num2str(abs_layer) ').wavelength])/nr_of_rays];']);
                            A_all_layers(row,2)=eval(['A_all_layers(row,2)+A_' num2str(abs_layer) '(row,2)']);
                        end
                        
                        T_tot(row,1:2)=[lambda_batch length([T_tot_struct.wavelength])/nr_of_rays];
                        
                        error_tot(row,1:2)=[lambda_batch length([error_tot_struct.wavelength])/nr_of_rays];
                        interrupt_tot(row,1:2)=[lambda_batch length([interrupt_tot_struct.wavelength])/nr_of_rays];
                        
                        %% Creating generation profile
                        cd(Gen_folder);
                        if gen_create==1
                            start=0.001; %Smalest depth value of the generation curve,eccept zero
                            stop=cell2mat(d_layer(Substrate_pos));
                            DP=90; % Nr of points for the generation profile (another three points will always be added to this value)
                            f=nthroot(stop/2/start,DP/2); % Calculation of a factor making the depth value increaing exponentially (derived from formula: d_layer/2=start*f^i where i=[0:1:steps/2])
                            depth=[0 start];
                            if lambda_batch<=960;
                                for ii=1:DP
                                    if ii<=DP/2
                                        depth(2+ii)=depth(2+ii-1)*f;
                                    else
                                        depth(2+ii)=depth(2+ii-1)+(depth(DP-ii+3)-depth(DP-ii+2)); % The point distribution calculated for the first half of the points is mirrord to the second half
                                    end
                                end
                                depth(length(depth)+1)=stop; % Final depth value is added to array so that the total array length is DP+3
                            else
                                depth=[0 2.^([0:DP+1].*log2(stop)/(DP+1))]; % Creates
                            end
                            
                            depth_eff=depth+sum(cell2mat(d_layer(1:Substrate_pos-1)));
                            
                            Gen_eff = histcounts(-real([A_tot_struct([A_tot_struct.layer_position]==Substrate_pos).abs_loc_eff]),depth_eff);
                            Gen_eff=[0 Gen_eff]'; % The Gen variable has always one value less then the depth variable. And the first value for PC1D needs to be 0/0.
                            Gen_eff=[depth'-depth(1) Gen_eff];
                            
                            % **** Writing generation profile in ASCII-format with .gen-suffix ****
                            h_Js=6.62607e-34;
                            c=299792458;
                            
                            ph_num=100*(lambda_batch/1e9)/(h_Js*c)/1e4; % specific nr of photons per cm� and J at a certain wavelength
                            
                            fid = fopen(['Gen_' num2str(lambda_batch) '.gen'], 'wt');
                            for i=1:length(Gen_eff(:,1))
                                fprintf(fid, '%f\t' , [Gen_eff(i,1) sum(Gen_eff(1:i,2))*ph_num/sum(Gen_eff(1:end,2))]); % Dividing through the total sum is done to normalize the generation curve to 1
                                fprintf(fid, '\n');
                                Gen_PC1D(i,1:2)=[Gen_eff(i,1) sum(Gen_eff(1:i,2))*ph_num/sum(Gen_eff(1:end,2))];
                            end
                            fclose(fid);
                            assignin('base', ['Gen_PC1D_' num2str(lambda_batch)], Gen_PC1D)
                        end
                        
                    end
                    
                    %% TESTING if sum of all processes equals 1
                    
                    if abs(sum(R_tot(:,2)+A_fi(:,2)+A_bb(:,2)+A_AR(:,2)+A_all_layers(:,2)+T_tot(:,2)+error_tot(:,2)+interrupt_tot(:,2))/row-1)>0.0001
                        errordlg('SOME RAYS WERE LOST!')
                        R_tot(:,2)+A_fi(:,2)+A_bb(:,2)+A_AR(:,2)+A_all_layers(:,2)+T_tot(:,2)+error_tot(:,2)+interrupt_tot(:,2)
                        return
                    end
                    
                    %% Saving all variables and cleaning up workspace
                    save([datestr(now,formatOut) '_Results_batch_' num2str(batch) '_angle_' num2str(theta) '.mat']);
                    
                                        
                end
            end
        end
    end
end
clear all


