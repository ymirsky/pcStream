function [u,s,total_mass,counter,model_base,model_var,used,method,t]=brand_update_6_st_fast_no_m_boost_noextra_bgu...
    (A,approx_rank,u,s,total_mass,counter,used,t)
%{
Copyright 2016 Tal Halpern

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    *  Non commercial use only
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the names of the contributors nor of their affiliated 
      institutions may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

For questions, please contact Tal Halpern (talhalpern10@gmail.com)
%}

   

split_calc=0;
thr=10^-12;
A=A';
temp_rank=approx_rank+1;
[row_A,column_A]=size(A);
% if to_pad==1
%     A=[zeros(row_A,1) A];
% end
       
temp_rank=approx_rank+1;
[row_A,column_A]=size(A);
row=row_A;
if row==approx_rank
    force_no_direction_add=1;
else
    force_no_direction_add=0;
end
m_count=0;
direction_add=0;
local_counter_total=zeros(1,column_A);
global_counter_total=zeros(1,column_A);
chance_data=zeros(2,column_A);
method=zeros(1,column_A);


previos_parallel=0;
u_built=u(:,1:approx_rank);
% initial_residual=get_residual_simple(A,norm_A,u_built);
% %-------------------------------------------------
% now doing the rest of the work
% %-------------------------------------------------
u_small_rotation=1;

for term_2=1:column_A
    %term_2/column_A
%     if previos_parallel==0
%         if min(diag(u'*u))<0.999
%             'wait'
%         end
%     else
%          if min(diag(u_small_rotation'*u'*u*u_small_rotation))<0.999
%             'wait'
%          end
%     end

        
    changed=1;%0 %for the residual calc
    local_counter=0;%0
    [row_temp,column_temp]=size(s);%0
    

    orth_used=0;%0
    paralel_used=0;%0
    orth_large=0;%0
    flip_only=0;%0
    do_nothing=0;%0
    only_paralel=0;%0
    complete_svd=0;%0
    only_orth_draw=0;%0

    % %-------------------------------------------------
    % initial settings
    % %-------------------------------------------------
    x=A(:,term_2);%0
    norm_x=(norm(x))^2;%m
    local_counter=local_counter+row;
    m_count=m_count+1;
%     total_mass=total_mass+sqrt(norm_x);%0
    total_mass=total_mass+norm_x;
    counter=counter+1;%0
    avg_mass=total_mass/counter;%0

    column=temp_rank;%0
    if previos_parallel==0
        m=u'*x;%m(k+1)
        local_counter=local_counter+row*temp_rank;
        m_count=m_count+temp_rank;
    else
        m_temp=u'*x;%m(k+1)
        m_count=m_count+temp_rank;
        m=u_small_rotation'*m_temp;%(k+1)^2
        local_counter=local_counter+row*temp_rank+temp_rank^2;
    end

    norm_parallel=norm(m);%(k+1)
    norm_parallel_squre=norm_parallel^2;%0
    local_counter=local_counter+temp_rank;
    r_a_squre=norm_x-norm_parallel_squre;%0
    r_a=sqrt(r_a_squre);%0
     if force_no_direction_add==0
        smallest_sin_val=s(column,column);%0
     end
    chance_orth=0;%0
    chance_parallel=0;%0


    %----------------
    %draw orth
    %----------------
    if force_no_direction_add==0
        if r_a<thr
            r_a=0;%0
        else
            chance_orth=r_a_squre/avg_mass;%0
                %             a=r_a/sqrt(norm_x);
                %             b=sqrt(norm_x)/avg_mass;
                %             chance_orth=(a+b)/2;%0
            chance_orth=min(chance_orth,1);%0
            chance_orth=chance_orth*(1-1/(t+1));
            if r_a<smallest_sin_val%||r_a>=smallest_sin_val
                %orth_large=0;
                %chance_orth=sqrt(r_a_squre/norm_x)*(sqrt(norm_x)/avg_mass);%0
%                 chance_orth=r_a/avg_mass;%0
                
                %             chance_orth=chance_orth^2;
                
                temp=rand(1,1);%0
                if temp<=chance_orth
                    orth_used=1;%0
                    direction_add=direction_add+1;
                    t=1;
                else
                    r_a=0;%0
                    t=t+1;
                end
            else
                temp=rand(1,1);%0
                if temp<=chance_orth
                    orth_large=1;%0
                    direction_add=direction_add+1;
                    t=1;
                else
                    r_a=0;%0
                    t=t+1;
                end
%                 orth_large=0;%0
%                 chance_orth=1;%0
%                 direction_add=direction_add+1;
            end
        end
        chance_data(1,term_2)=chance_orth;
    else
        chance_orth=0;
        r_a=0;
        orth_used=0;
        orth_large=0;
    end
    %----------------
    %draw parallel
    %----------------
 
    norm_s=norm(diag(s));%(k+1)
    norm_s_squre=norm_s^2;%0
    local_counter=local_counter+temp_rank;
    scailing=norm_parallel*norm_s;%0
    temp_corelation_val=m'*diag(s);%(k+1)
    local_counter=local_counter+temp_rank;
    corelation_val=temp_corelation_val/scailing;%0
    parallel_control=1-abs(corelation_val);%0
    
%     chance_parallel=norm_parallel/avg_mass;%0
     chance_parallel=norm_parallel_squre/avg_mass;%0
    chance_parallel=min(chance_parallel,1);%0
    chance_parallel=parallel_control*chance_parallel;%0
%     chance_parallel=chance_parallel^2;
chance_data(2,term_2)=chance_parallel;
        
     
    temp=rand(1,1);%0
%     if r_a~=0
%         temp=-1;%if orth_use then also do parrallel
%     end
%     if split_calc~=0&&r_a~=0
%         temp=1.5;
%     end
temp=0;
    if norm_parallel<thr
        norm_parallel=0;%0
    else
        if temp<=chance_parallel
            paralel_used=1;%0
        else
            norm_parallel=0;%0
        end
    end
       

    %----------------------
    % calculating the svd
    %---------------------
    
    
    

    if norm_parallel==0&&orth_large==1
%         'ipca enterd method 1 = wrong'
%         return
        if previos_parallel==0
            p=x-u*m;%m(k+1)
            local_counter=local_counter+row*temp_rank;
            m_count=m_count+temp_rank;
        else
            p=x-u*m_temp;%m(k+1)
            local_counter=local_counter+row*temp_rank;
            m_count=m_count+temp_rank;
        end
        if previos_parallel==1
            u=u*u_small_rotation;%m(k+1)^2
            local_counter=local_counter+row*(temp_rank^2);
            m_count=m_count+temp_rank^2;
        end
        m_zeros=zeros(size(m));%0
        s=[s m_zeros;zeros(1,column) r_a];%0
        u=[u p/r_a];%m
        local_counter=local_counter+row;
        m_count=m_count+1;
        Per=fix_sizes(s);%0
        u=u*Per';%0
        s=Per*s*Per';%0
        u=u(:,1:column);%0
        s=s(1:column,1:column);%0
        
        flip_only=1;%0
        method(1,term_2)=1;%0
        previos_parallel=0;%0
    elseif norm_parallel==0&&orth_used==1
        %          s(column,column)=sqrt(s(column,column)^2+r_a^2);
        if previos_parallel==0
            p=x-u*m;%m(k+1)
            local_counter=local_counter+row*temp_rank;
            m_count=m_count+temp_rank;
        else
            p=x-u*m_temp;%m(k+1)
            local_counter=local_counter+row*temp_rank;
            m_count=m_count+temp_rank;
        end
        if previos_parallel==1
            u=u*u_small_rotation;%m(k+1)^2
            local_counter=local_counter+row*(temp_rank^2);
            m_count=m_count+temp_rank^2;
        end
        u(:,column)=p/r_a;%m
        local_counter=local_counter+row;
%         s(column,column)=s(column,column)/2;
%         s(column,column)=min(s(column,column),1/chance_orth);
        m_count=m_count+1;
        only_orth_draw=1;%0
        method(1,term_2)=2;%0
        previos_parallel=0;%0
%         'ipca enterd method 2 = wrong'
%         return
    elseif norm_parallel~=0&&r_a==0
        if force_no_direction_add==0
            K=[s m;zeros(1,column) 0];%0
            [u_temp,s]=svd(K,'econ');%(k+2)^3
            local_counter=local_counter+(temp_rank+1)^3;
            u_temp=u_temp(1:column,1:column);%0
            s=s(1:column,1:column);%0
        else
            K=[s m;zeros(1,approx_rank) 0];
            [u_temp,s]=svd(K,'econ');%(k+2)^3
            local_counter=local_counter+(temp_rank+1)^3;
            u_temp=u_temp(1:approx_rank,1:approx_rank);%0
            s=s(1:approx_rank,1:approx_rank);%0
        end
        
       

        
        if previos_parallel==1
            u_small_rotation=u_small_rotation*u_temp;%(k+1)^3
            local_counter=local_counter+temp_rank^3;
        else
            u_small_rotation=u_temp;%0
        end
        only_paralel=1;%0
        method(1,term_2)=3;%0
        previos_parallel=1;%0
    elseif norm_parallel~=0&&r_a~=0
        if orth_large~=1

            if previos_parallel==0
                p=x-u*m;%m(k+1)
                local_counter=local_counter+row*temp_rank;
                m_count=m_count+temp_rank;
            else
                p=x-u*m_temp;%m(k+1)
                local_counter=local_counter+row*temp_rank;
                m_count=m_count+temp_rank;
            end
            if previos_parallel==1
                u=u*u_small_rotation;%m(k+1)^2
                local_counter=local_counter+row*(temp_rank^2);
                m_count=m_count+temp_rank^2;
            end
%              sin_val_ratio=smallest_sin_val/r_a;%0
%             currant_wieght=norm_s_squre+norm_parallel_squre+r_a_squre;%0
%              m=m*sqrt((sin_val_ratio));%(k+1)
            %parallel_importance=m/norm(m);
            
               %m=m*sin_val_ratio;%(k+1)
             %local_counter=local_counter+temp_rank;
             smallest_sin_val=s(column,column);
             new_norm=sqrt(norm_x+smallest_sin_val^2);
            ratio=new_norm/sqrt(norm_x);
            to_use=r_a*ratio;
           K=[s m;zeros(1,column) to_use];% 
%             K=[s m;zeros(1,column) smallest_sin_val];%0
            u=[u p/r_a];%m
            local_counter=local_counter+row;
            m_count=m_count+1;
            [u_temp,s]=svd(K,'econ');%(k+2)^3
            local_counter=local_counter+(temp_rank+1)^3;
%             complicated
%                 s_squere=s.^2;%(k+2)
%                 local_counter=local_counter+(temp_rank+1);
%                 sum_s_squere=sum(sum(s_squere));%0
%                 borrowed_mass=sum_s_squere-currant_wieght;%0
%     %                  singular_vec=importance=m/norm(m);
%     %                 weight_dist=1-parallel_importance;
%     %                 weight_dist=weight_dist/norm(weight_dist);
%     %                 borrowed_mass=borrowed_mass-s_squere(temp_rank+1,temp_rank+1);
%     %                 s_squere=s_squere(1:column,1:column);
%     %                 s=s_squere-diag(borrowed_mass*weight_dist);%(k+2)
%     %                 local_counter=local_counter+(temp_rank+1);
%     %                 s=max(s,0);
% %                 singular_importance=diag(s)/norm(diag(s));
% %                 singular_importance=abs(singular_importance);
% %                 s=s_squere-diag(borrowed_mass*singular_importance);%(k+2)
%                 s=s_squere-s_squere*borrowed_mass/sum_s_squere;%(k+2)
%                 s=sqrt(s);%(k+1)- we soon truncate it back so thats why ot (k+2)
%                 local_counter=local_counter+temp_rank;
%                     %--------------
%                     %ido style
%                     %--------------
%                     s_squere=s.^2;%(k+2)
%                     s_squere=s_squere-s_squere(column+1,column+1)*eye(column+1);
%                     s=sqrt(s);
%                      %--------------
%                     %ido style end
%                     %--------------
                    
                u=u*u_temp;%m(k+1)(k+2)
                local_counter=local_counter+row*temp_rank*(temp_rank+1);
                m_count=m_count+temp_rank*(temp_rank+1);
% %end complicated
            u=u(:,1:column);%0
            s=s(1:column,1:column);%0
            method(1,term_2)=4;%0
            previos_parallel=0;%0
        else
%             'ipca enterd method 5 = wrong'
%             return
            K=[s m;zeros(1,column) r_a];%0
            if previos_parallel==0
                p=x-u*m;%m(k+1)
                local_counter=local_counter+row*temp_rank;
                 m_count=m_count+temp_rank;
            else
                p=x-u*m_temp;%m(k+1)
                local_counter=local_counter+row*temp_rank;
                m_count=m_count+temp_rank;
            end
            if previos_parallel==1
                u=u*u_small_rotation;%m(k+1)^2
                local_counter=local_counter+(row*temp_rank^2);
                m_count=m_count+temp_rank^2;
            end
            u=[u p/r_a];%m
            local_counter=local_counter+row;
             m_count=m_count+1;

            %              [u_temp,s]=svds(K,column+1);
            [u_temp,s]=svd(K,'econ');%(k+2)^3
            local_counter=local_counter+(temp_rank+1)^3;
            %              [junk,mix_max_weight]=max(u_temp,[],1);
            u=u*u_temp;%m(k+1)(k+2)
            local_counter=local_counter+row*temp_rank*(temp_rank+1);
            m_count=m_count+temp_rank*(temp_rank+1);
            u=u(:,1:column);%0
            s=s(1:column,1:column);%0
            method(1,term_2)=5;%0
            previos_parallel=0;%0

        end
        complete_svd=1;
    elseif norm_parallel==0&&r_a==0
%             norm_parallel=norm(m); %calculated before, now again due to code no real need
%             parallel_importance=abs(m/norm_parallel);%(k+1)
            s_importance=diag(s)/norm(diag(s));
            local_counter=local_counter+temp_rank;
%             s=s^2+diag(parallel_importance.^2*norm_parallel^2);%2(k+1)
            s=s^2+diag(s_importance.^2*norm_parallel^2);%2(k+1)
            s=sqrt(s);%(k+1)
            local_counter=local_counter+3*temp_rank;

            do_nothing=do_nothing+1;%0
            method(1,term_2)=6;%0
            changed=0;%0
    end
    if method(1,term_2)~=6
        used=used+1;
    end
%     local_counter_total(1,term_2)=local_counter;
%     if term_2==1
%         global_counter_total(1,term_2)=local_counter;
%     else
%         global_counter_total(1,term_2)=global_counter_total(1,term_2-1)+local_counter;
%     end
%     chance_data(:,term_2)=[chance_orth;chance_parallel];
%     if changed==1
%         if previos_parallel==1
%             u_built=u*u_small_rotation;
%             u_built=u_built(:,1:approx_rank);
%         else
%             u_built=u(:,1:approx_rank);
%         end
%     end
%     residual_local(1,term_2)=get_residual_simple(A,norm_A,u_built);
%     residual_global(1,term_2)=get_residual_simple(A_total,norm_A_total,u_built);

end


if previos_parallel==1
    u_built=u*u_small_rotation;
    if force_no_direction_add==0
        u_built=u_built(:,1:temp_rank);
    else
         u_built=u_built(:,1:approx_rank);
    end
    u=u_built;
end
m_count=m_count/(column_A-1+1);
m_count=m_count/approx_rank;


model_base=u(:,1:approx_rank);
model_var=s(1:approx_rank,1:approx_rank)^2*(1/(used-1));
model_var=diag(model_var);

