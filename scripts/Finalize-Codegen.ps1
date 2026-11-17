param(
    [string]$GeneratedDirectory = (Join-Path $PSScriptRoot '../generated/default')
)
$ErrorActionPreference = 'Stop'

# The Deluxe detour jumps back into sub_8275D670's existing stack frame.
# Emit its operations in the parent C++ function to retain that control flow.
$entry = 'DEFINE_REX_FUNC(sub_8275D670) {'
$unit = Get-ChildItem -LiteralPath $GeneratedDirectory -Filter 'rockband3deluxe_recomp.*.cpp' -File |
    Select-String -SimpleMatch -Pattern $entry -List |
    Select-Object -First 1
if (-not $unit) { throw 'Generated function sub_8275D670 is missing.' }

$text = [IO.File]::ReadAllText($unit.Path)
$start = $text.IndexOf($entry, [StringComparison]::Ordinal)
$end = [regex]::Match($text.Substring($start), '(?m)^}\r?$')
if (-not $end.Success) { throw 'Generated function sub_8275D670 has no end.' }
$function = $text.Substring($start, $end.Index)
if ($function.Contains('// RB3 Deluxe detour at 0x8275D6E0')) { return }

$nop = [regex]::new('(?m)(^\tctx\.r3\.s64 = ctx\.r11\.s64 \+ 8;\r?\n)^\t// nop[ \t]*(?=\r?$)')
if ($nop.Matches($function).Count -ne 1 -or $function -notmatch '(?m)^loc_8275D6F0:' -or
    $function -notmatch 'ctx\.lr = 0x8275D6E8;') {
    throw 'Generated module has an unexpected layout around the Deluxe detour.'
}
$tab = [string][char]9
$newline = if ($function.Contains(([string][char]13) + [char]10)) { ([string][char]13) + [char]10 } else { [string][char]10 }
$detour = @(
    '// RB3 Deluxe detour at 0x8275D6E0'
    'ctx.r4.u64 = REX_LOAD_U32(ctx.r3.u32 + 4);'
    'if (ctx.r4.s32 != 2) goto loc_8275D6F0;'
    'ctx.r4.u64 = ctx.r30.u64;'
) | ForEach-Object { $tab + $_ }
$patched = $nop.Replace($function, ('$1' + ($detour -join $newline)), 1)
$result = $text.Substring(0, $start) + $patched + $text.Substring($start + $end.Index)
[IO.File]::WriteAllText($unit.Path, $result, [Text.UTF8Encoding]::new($false))
