﻿$profiledir = $Env:USERPROFILE 
$vcpkgdir = $profiledir + "\mumble-vcpkg"

$mumble_deps = "qt5-base",
               "qt5-svg",
               "qt5-tools",
               "grpc",
               "boost-accumulators",
               "opus",
               "poco",
               "libvorbis",
               "libogg",
               "libflac",
               "libsndfile",
               "libmariadb",
               "zlib",
               "zeroc-ice"

$ErrorActionPreference = 'Stop'

function vcpkg_install {
	Param(
		[string] $package,
		[string] $targetTriplet,
		[switch] $cleanAfterBuild = $false
	)
	
	if ($cleanAfterBuild) {
		./vcpkg.exe install "$package" --triplet "$targetTriplet" --clean-after-build
	} else {
		./vcpkg.exe install "$package" --triplet "$targetTriplet"
	}
	
	if (-not $?) {
		Write-Error("Failed at installing package $package ($targetTriplet)")
	}
}

$prevDir=pwd

try {
	Write-Host "Setting triplets for $Env:PROCESSOR_ARCHITECTURE"
	if ($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
		$triplet = "x64-windows-static-md"
		$xcompile_triplet = "x86-windows-static-md"
	} else {
		$triplet = "x86-windows-static-md"
	}

	Write-Host "Checking for $vcpkgdir..."
	if (-not (Test-Path $vcpkgdir)) {
		git clone https://github.com/Microsoft/vcpkg.git $vcpkgdir
	}

	if (Test-Path $vcpkgdir) {
		if (-not (Test-Path $vcpkgdir/ports/zeroc-ice)) {
			Write-Host "Adding ports for ZeroC Ice..."
			Copy-Item -Path ./helpers/vcpkg/ports/zeroc-ice -Destination $vcpkgdir/ports -Recurse
		}
		
		cd $vcpkgdir

		if (-not (Test-Path -LiteralPath $vcpkgdir/vcpkg.exe)) {
			Write-Host "Installing vcpkg..."
			./bootstrap-vcpkg.bat -disableMetrics
			./vcpkg.exe integrate install
		}

		vcpkg_install -package mdnsresponder -targetTriplet $triplet
		vcpkg_install -package icu -targetTriplet $triplet

		if ($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
			Write-Host "Installing cross compile packages..."
			vcpkg_install -package boost-optional:$xcompile_triplet -targetTriplet $xcompile_triplet -cleanAfterBuild
		}

		Write-Host "Beginning package install..."

		foreach ($dep in $mumble_deps) {
			Write-Host("---------------------------------------")
			Write-Host("> Installing Mumble dependency $dep ...")
			Write-Host("---------------------------------------")
			
			vcpkg_install -package $dep -targetTriplet $triplet -cleanAfterBuild
		}
	}
} catch {
	# rethrow
	throw $_
} finally {
	# restore previous directory
	cd $prevDir
}
