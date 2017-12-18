#!/usr/bin/perl -w

##
## sample usage:
##


# use module
use Data::Dumper;
use Cwd 'realpath';
use Cwd;
use File::Spec;
use File::Find;
use File::Basename;
use File::Path;

my $ANTSPATH = "/data/picsl/jtduda/data/TBI-Long/bin/";

my $baseDirectory = "/data/picsl/jtduda/data/TBI-Long";
my $templateDirectory = "/data/picsl/jtduda/data/TBI-Long/template/";
my $outputDirectory = "${baseDirectory}/longact_denoise_cook_unbiased/";

my $brainExtractionTemplate = "${templateDirectory}/TBI_template0.nii.gz";
my $brainTemplateSkullStripped = "${templateDirectory}/TBI_template0_BrainExtractionBrain.nii.gz";
my $brainExtractionProbabilityMask = "${templateDirectory}/TBI_template0_BrainExtractionMaskPrior.nii.gz";
my $brainExtractionMask = "${templateDirectory}/TBI_template0_BrainExtractionMask.nii.gz";
my $brainParcellationProbabilityMask = "${templateDirectory}/Priors/TBI_template0_Priors%d.nii.gz";

my @atlasSubs = ("1001","1002","1006","1009","1010","1012","1013","1015","1036","1017","1003","1004","1005","1018","1104","1107","1113","1116","1119","1122");
my $atlasString = "";
my $labelsString = "";
foreach my $id (@atlasSubs) {
  $atlasString = $atlasString." -a /data/picsl/jtduda/data/Templates/OASIS30/Brains/".$id."_3.nii.gz";
  $labelsString = $labelsString." -l /data/picsl/jtduda/data/Templates/OASIS30/Segmentations6Class/".$id."_3_seg.nii.gz";
}

my @subjectDirs = <${baseDirectory}/subjects/*>;
#my @subjects =( "p014","p017","p019","p027","p029","p032","p037","p044","p046","p056","p061","p064","p065" );

for( my $d = 0; $d < @subjectDirs; $d++ )
#for( my $d = 0; $d < @subjects; $d++ )
  {
  my $subjectDir = $subjectDirs[$d];
  my @comps = split( '/', $subjectDir );
  my $subjectId = $comps[-1];

  #my $subjectId = $subjects[$d];
  #my $subjectDir = "/data/picsl/jtduda/data/TBI-Long/subjects_baseline/".$subjectId;

  print "SubjectID: $subjectId\n";

  my @t1s = <${subjectDir}/*/MPRAGE/*MPRAGE.nii.gz>;

  my @masks = <${subjectDir}/Lesion/*lesionmask.nii.gz>;


  my @timePointImages = ();
  for( my $k = 0; $k < @t1s; $k++ )
    {
    push( @timePointImages, $t1s[$k] );
    #push( @timePointImages, $t2s[$k] );
    }

  ( my $localOutputDirectory = $subjectDir ) =~ s/subjects/longact_denoise_cook_unbiased/;
  my $runIt=0;

  if( ! -d $localOutputDirectory )
    {
    mkpath( $localOutputDirectory );
    $runIt = 1;
    }
  print "$localOutputDirectory\n";

  my $commandFile = "${localOutputDirectory}/antsLongitudinalThicknessCommand.sh";

  my @act = glob("${localOutputDirectory}/*CorticalThicknessNormalizedToTemplate.nii.gz" );
  my @lact = glob("${localOutputDirectory}/*MPRAGE*/*CorticalThicknessNormalizedToTemplate.nii.gz");

  #print "@act\n";
  #print "@lact\n";
  if ( ( scalar(@act)==0 ) && ( scalar(@lact)==0) ) {
    print ("  - Needs to run\n");
    $runIt = 1;
  }

  if ( $runIt ) {

    print "$commandFile\n";

    open( FILE, ">${commandFile}" );
    print FILE "#!/bin/bash\n\n";

    print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";
    print FILE "export ANTSPATH=$ANTSPATH\n";

    print FILE "\n";

    my $lesionFlag = "";
    if ( scalar(@masks) > 0 ) {
      $lesionFlag = " -x $masks[0] ";
    }

    my @antsCommands = ();
    $antsCommands[0] = "${ANTSPATH}/antsLongitudinalCorticalThicknessTBI.sh \\";
    $antsCommands[1] = "   -d 3 $atlasString $labelsString \\";
    $antsCommands[2] = "   -o ${localOutputDirectory}/ants \\";
    $antsCommands[3] = "   -c 0 \\";
    $antsCommands[4] = "   -t $brainTemplateSkullStripped \\";
    $antsCommands[5] = "   -e $brainExtractionTemplate \\";
    $antsCommands[6] = "   -m $brainExtractionProbabilityMask \\";
    $antsCommands[7] = "   -f $brainExtractionMask \\";
    $antsCommands[8] = "   -p $brainParcellationProbabilityMask \\";
    $antsCommands[9] = "   -r 0 -q 2 -k 1 $lesionFlag \\"; #
    $antsCommands[10]= "   @timePointImages";

    for( my $k = 0; $k < @antsCommands; $k++ )
      {
      if( $k < @antsCommands )
        {
        print FILE "$antsCommands[$k]\n";
        }
      }
    print FILE "\n";
    close( FILE );

    system( "qsub -l h_vmem=8.0G,s_vmem=7.9G -binding linear:1 -pe unihost 1 -o ${localOutputDirectory}/${subjectId}_lact_denoise_lowprior.stdout -e ${localOutputDirectory}/${subjectId}_lact_denoise_lowprior.stderr $commandFile" );
    #print("\n");
    sleep(1);
    }
  }
