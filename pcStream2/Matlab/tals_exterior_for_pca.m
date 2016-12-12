function [u,s,total_mass,counter,model_base,model_var,approx_rank,used,t,method]=tals_exterior_for_pca(A,approx_rank,u,s,total_mass,counter,rho,used,t)
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

if isempty(u)
    A=A';
    [row,counter]=size(A);
    [u_temp,s_temp]=svd(A,'econ');
    approx_rank=find_rank(s_temp,rho);
    if approx_rank==row
        u=u_temp;
        s=s_temp;
    else
        u=u_temp(:,1:approx_rank+1);
        s=s_temp(1:approx_rank+1,1:approx_rank+1);
    end
    used=counter;
    model_base=u(:,1:approx_rank);
    model_var=diag(s(1:approx_rank,1:approx_rank));
    model_var=model_var.^2*(1/(used-1));
   
    [~,total_mass]=get_avg_vec_norm(A);
    total_mass=norm(A,'fro')^2;
    t=1;
   
    
    
else
%     [u,s,total_mass,counter,model_base,model_var,used,method]=brand_update_accelerate_learn_6_st_fast_bgu_2(A,approx_rank,u,s,total_mass,counter,to_pad,used);
    [u,s,total_mass,counter,model_base,model_var,used,method,t]=brand_update_6_st_fast_no_m_boost_noextra_bgu(A,approx_rank,u,s,total_mass,counter,used,t);
end