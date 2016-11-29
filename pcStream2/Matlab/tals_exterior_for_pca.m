function [u,s,total_mass,counter,model_base,model_var,approx_rank,used,t,method]=tals_exterior_for_pca(A,approx_rank,u,s,total_mass,counter,rho,used,t)


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