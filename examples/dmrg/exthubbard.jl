using ITensors

#
# DMRG calculation of the extended Hubbard model
# ground state wavefunction, and spin densities
#

let
  N = 20
  Npart = 10
  t1 = 1.0
  t2 = 0.2
  U  = 1.0
  V1 = 0.5

  sites = siteinds("Electron",N; conserve_qns=true)

  ampo = AutoMPO()
  for i=1:N
    ampo += (U,"Nupdn",i)
  end
  for b=1:N-1
    ampo += (-t1,"Cdagup",b,"Cup",b+1)
    ampo += (-t1,"Cdagup",b+1,"Cup",b)
    ampo += (-t1,"Cdagdn",b,"Cdn",b+1)
    ampo += (-t1,"Cdagdn",b+1,"Cdn",b)
    ampo += (V1,"Ntot",b,"Ntot",b+1)
  end
  for b=1:N-2
    ampo += (-t2,"Cdagup",b,"Cup",b+2)
    ampo += (-t2,"Cdagup",b+2,"Cup",b)
    ampo += (-t2,"Cdagdn",b,"Cdn",b+2)
    ampo += (-t2,"Cdagdn",b+2,"Cdn",b)
  end
  H = MPO(ampo,sites)

  sweeps = Sweeps(6)
  maxdim!(sweeps,50,100,200,400,800,800)
  cutoff!(sweeps,1E-12)
  @show sweeps

  state = fill("Emp",N)
  p = Npart
  for i=N:-1:1
    if p > i
      println("Doubly occupying site $i")
      state[i] = "UpDn"
      p -= 2
    elseif p > 0
      println("Singly occupying site $i")
      state[i] = (isodd(i) ? "Up" : "Dn")
      p -= 1
    end
  end
  psi0 = productMPS(sites,state)
  @show flux(psi0)

  energy,psi = dmrg(H,psi0,sweeps)

  upd = fill(0.0,N)
  dnd = fill(0.0,N)
  for j=1:N
    orthogonalize!(psi,j)
    upd[j] = scalar(dag(prime(psi[j],"Site"))*op(sites,"Nup",j)*psi[j])
    dnd[j] = scalar(dag(prime(psi[j],"Site"))*op(sites,"Ndn",j)*psi[j])
  end

  println("Up Density:")
  for j=1:N
    println("$j $(upd[j])")
  end
  println()

  println("Dn Density:")
  for j=1:N
    println("$j $(dnd[j])")
  end
  println()

  println("Total Density:")
  for j=1:N
    println("$j $(upd[j]+dnd[j])")
  end
  println()

  println("\nGround State Energy = $energy")

end
