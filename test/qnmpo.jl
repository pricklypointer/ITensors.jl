using ITensors,
      Test

@testset "MPO Basics" begin
  N = 6
  sites = [Index(QN(-1)=>1, QN(1)=>1; tags="Site,n=$n") for n=1:N]
  links = [Index(QN()=>1; tags="Links,l=$n") for n=1:N-1]
  @test length(MPO()) == 0
  #O = MPO(sites)
  O = MPO(N)
  for i in 1:length(O)
    O[i] = randomITensor(QN(), sites[i], sites[i]')
  end
  @test length(O) == N

  O[1] = zeroITensor(sites[1], prime(sites[1]))
  @test hasind(O[1],sites[1])
  @test hasind(O[1],prime(sites[1]))
  P = copy(O)
  @test hasind(P[1],sites[1])
  @test hasind(P[1],prime(sites[1]))
  # test constructor from Vector{ITensor}

  K = MPO(N)
  K[1] = randomITensor(QN(), dag(sites[1]), sites[1]', links[1])
  for i in 2:N-1
    K[i] = randomITensor(QN(), dag(sites[i]), sites[i]', dag(links[i-1]), links[i])
  end
  K[N] = randomITensor(QN(), dag(sites[N]), sites[N]', dag(links[N-1]))

  J = MPO(N)
  J[1] = randomITensor(QN(), dag(sites[1]), sites[1]', links[1])
  for i in 2:N-1
    J[i] = randomITensor(QN(), dag(sites[i]), sites[i]', dag(links[i-1]), links[i])
  end
  J[N] = randomITensor(QN(), dag(sites[N]), sites[N]', dag(links[N-1]))

  L = MPO(N)
  L[1] = randomITensor(QN(), dag(sites[1]), sites[1]', links[1])
  for i in 2:N-1
    L[i] = randomITensor(QN(), dag(sites[i]), sites[i]', dag(links[i-1]), links[i])
  end
  L[N] = randomITensor(QN(), dag(sites[N]), sites[N]', dag(links[N-1]))

  @test length(K) == N
  @test ITensors.data(MPO(copy(ITensors.data(K)))) == ITensors.data(K)

  phi = MPS(N)
  phi[1] = randomITensor(QN(-1), sites[1], links[1])
  for i in 2:N-1
    phi[i] = randomITensor(QN(-1), sites[i], dag(links[i-1]), links[i])
  end
  phi[N] = randomITensor(QN(-1), sites[N], dag(links[N-1]))

  psi = MPS(N)
  psi[1] = randomITensor(QN(-1), sites[1], links[1])
  for i in 2:N-1
    psi[i] = randomITensor(QN(-1), sites[i], dag(links[i-1]), links[i])
  end
  psi[N] = randomITensor(QN(-1), sites[N], dag(links[N-1]))

  @testset "orthogonalize!" begin
    orthogonalize!(phi, 1)
    orthogonalize!(K, 1)
    orig_inner = ⋅(phi, K, phi)
    orthogonalize!(phi, div(N, 2))
    orthogonalize!(K, div(N, 2))
    @test ⋅(phi, K, phi) ≈ orig_inner
  end

  @testset "inner <y|A|x>" begin
    @test maxlinkdim(K) == 1
    phidag = dag(phi)
    prime!(phidag)
    phiKpsi = phidag[1]*K[1]*psi[1]
    for j = 2:N
      phiKpsi *= phidag[j]*K[j]*psi[j]
    end
    @test phiKpsi[] ≈ inner(phi, K, psi)
  end

  @testset "inner <By|A|x>" begin
    phidag = dag(phi)
    prime!(phidag, 2)
    Jdag = dag(J)
    prime!(Jdag)
    for j ∈ eachindex(Jdag)
      swapprime!(Jdag[j],2,3)
      swapprime!(Jdag[j],1,2)
      swapprime!(Jdag[j],3,1)
    end

    phiJdagKpsi = phidag[1]*Jdag[1]*K[1]*psi[1]
    for j ∈ eachindex(psi)[2:end]
      phiJdagKpsi = phiJdagKpsi*phidag[j]*Jdag[j]*K[j]*psi[j]
    end

    @test phiJdagKpsi[] ≈ inner(J,phi,K,psi)

    badsites = [Index(2,"Site") for n=1:N+1]
    badpsi = randomMPS(badsites)
    @test_throws DimensionMismatch inner(J,phi,K,badpsi)
  end

  @testset "error_contract" begin
    dist = sqrt(abs(1 + (inner(phi,phi) - 2*real(inner(phi,K,psi)))
                        /inner(K,psi,K,psi)))
    @test dist ≈ error_contract(phi,K,psi)
  end

  @testset "contract" begin
    @test maxlinkdim(K) == 1
    psi_out = contract(K, psi, maxdim=1)
    @test inner(phi,psi_out) ≈ inner(phi,K,psi)
    @test_throws ArgumentError contract(K, psi, method="fakemethod")
  end

  # TODO: implement add for QN MPOs and add this test back
  #@testset "add(::MPO, ::MPO)" begin
  #  shsites = siteinds("S=1/2", N)
  #  M = add(K, L)
  #  @test length(M) == N
  #  k_psi = contract(K, psi, maxdim=1)
  #  l_psi = contract(L, psi, maxdim=1)
  #  @test inner(psi, k_psi + l_psi) ≈ ⋅(psi, M, psi) atol=5e-3
  #  @test inner(psi, sum([k_psi, l_psi])) ≈ dot(psi, M, psi) atol=5e-3
  #  for dim in 2:4
  #    shsites = siteinds("S=1/2",N)
  #    K = basicRandomMPO(N, shsites; dim=dim)
  #    L = basicRandomMPO(N, shsites; dim=dim)
  #    M = K + L
  #    @test length(M) == N
  #    psi = randomMPS(shsites)
  #    k_psi = contract(K, psi)
  #    l_psi = contract(L, psi)
  #    @test inner(psi, k_psi + l_psi) ≈ dot(psi, M, psi) atol=5e-3
  #    @test inner(psi, sum([k_psi, l_psi])) ≈ inner(psi, M, psi) atol=5e-3
  #    psi = randomMPS(shsites)
  #    M = add(K, L; cutoff=1E-9)
  #    k_psi = contract(K, psi)
  #    l_psi = contract(L, psi)
  #    @test inner(psi, k_psi + l_psi) ≈ inner(psi, M, psi) atol=5e-3
  #  end
  #end

  @testset "contract(::MPO, ::MPO)" begin
    @test maxlinkdim(K) == 1
    @test maxlinkdim(L) == 1
    KL = contract(prime(K), L; maxdim = 1)
    Lpsi = contract(L, psi; maxdim = 1)
    psi_kl_out = contract(prime(K), Lpsi; maxdim = 1)
    @test inner(psi,KL,psi) ≈ inner(psi, psi_kl_out) atol=5e-3
  end

  @testset "*(::MPO, ::MPO)" begin
    @test maxlinkdim(K) == 1
    @test maxlinkdim(L) == 1
    KL = *(prime(K), L; maxdim = 1)
    psi_kl_out = *(prime(K), *(L, psi; maxdim = 1); maxdim = 1)
    @test ⋅(psi, KL, psi) ≈ dot(psi, psi_kl_out) atol=5e-3
  end

  sites = siteinds("S=1/2",N)
  O = MPO(sites,"Sz")
  @test length(O) == N # just make sure this works

  @test_throws ArgumentError randomMPO(sites, 2)
  @test isnothing(linkind(MPO(N, fill(ITensor(), N), 0, N + 1), 1))
end

nothing
