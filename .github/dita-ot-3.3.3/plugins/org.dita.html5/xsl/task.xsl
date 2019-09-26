<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                version="2.0"
                exclude-result-prefixes="xs dita-ot related-links dita2html ditamsg ">
  
  <!-- Determines whether to generate titles for task sections. Values are YES and NO. -->
  <xsl:param name="GENERATE-TASK-LABELS" select="'NO'"/>
  
  <!-- == TASK UNIQUE SUBSTRUCTURES == -->
  
  <xsl:template match="*[contains(@class,' task/taskbody ')]" name="topic.task.taskbody">
  <div>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <!-- here, you can generate a toc based on what's a child of body -->
    <!--xsl:call-template name="gen-sect-ptoc"/--><!-- Works; not always wanted, though; could add a param to enable it.-->
  
    <!-- Added for DITA 1.1 "Shortdesc proposal" -->
    <!-- get the abstract para -->
    <xsl:apply-templates select="preceding-sibling::*[contains(@class,' topic/abstract ')]" mode="outofline"/>
  
    <!-- get the short descr para -->
    <xsl:apply-templates select="preceding-sibling::*[contains(@class,' topic/shortdesc ')]" mode="outofline"/>
  
    <!-- Insert pre-req links here, after shortdesc - unless there is a prereq section about -->
    <xsl:if test="not(*[contains(@class,' task/prereq ')])">
     <xsl:apply-templates select="following-sibling::*[contains(@class,' topic/related-links ')]" mode="prereqs"/>
    </xsl:if>
  
    <xsl:apply-templates/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/prereq ')]" name="topic.task.prereq">
  <section>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="gen-toc-id"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="dita2html:section-heading">
      <!--xsl:with-param name="deftitle"></xsl:with-param-->
      <xsl:with-param name="defaulttitle"></xsl:with-param>
    </xsl:apply-templates>
    <!-- Title is not allowed now, but if we add it, make sure it is processed as in section -->
    <xsl:apply-templates select="*[not(contains(@class,' topic/title '))] | text() | comment() | processing-instruction()"/>
    
    <!-- Insert pre-req links - after prereq section -->
    <xsl:apply-templates select="../following-sibling::*[contains(@class,' topic/related-links ')]" mode="prereqs"/>
    
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <xsl:if test="$link-top-section='yes'"> <!-- optional return to top - not used -->
      <p>
        <xsl:call-template name="style">
          <xsl:with-param name="contents">
            <xsl:text>text-align:left;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
        <a href="#TOP">
        <!--xsl:value-of select="$deftxt-linktop"/-->
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Return to Top'"/>
        </xsl:call-template>
      </a></p>
    </xsl:if>
  </section>
  </xsl:template>
  
  <xsl:template match="*" mode="make-steps-compact">
    <xsl:choose>
      <!-- expand the list when one of the steps has any of these: "*/*" = step context -->
      <xsl:when test="*/*[contains(@class,' task/info ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/stepxmp ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/tutorialinfo ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/stepresult ')]">yes</xsl:when>
      <xsl:otherwise>no</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps ')]" name="topic.task.steps">
   <!-- If there's one of these elements somewhere in a step, expand the whole step list -->
    <xsl:variable name="step_expand"> <!-- set & save step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="common-processing-within-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
      <xsl:with-param name="list-type" select="'ol'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps ') or contains(@class,' task/steps-unordered ')]"
                mode="common-processing-within-steps">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type">
      <xsl:choose>
        <xsl:when test="contains(@class,' task/steps ')">ol</xsl:when>
        <xsl:otherwise>ul</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <section>
      <xsl:call-template name="gen-toc-id"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="generate-task-label">
        <xsl:with-param name="use-label">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id">
              <xsl:choose>
                <xsl:when test="contains(@class,' task/steps ')">task_procedure</xsl:when>
                <xsl:otherwise>task_procedure_unordered</xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:with-param>
      </xsl:apply-templates>
      <xsl:choose>
        <xsl:when test="*[contains(@class,' task/step ')] and not(*[contains(@class,' task/step ')][2])">
          <!-- Single step. Process any stepsection before the step (cannot appear after). -->
          <xsl:apply-templates select="*[contains(@class,' task/stepsection ')]"/>
          <xsl:apply-templates select="*[contains(@class,' task/step ')]" mode="onestep">
            <xsl:with-param name="step_expand" select="$step_expand"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="not(*[contains(@class,' task/stepsection ')])">
          <xsl:apply-templates select="." mode="step-elements-with-no-stepsection">
            <xsl:with-param name="step_expand" select="$step_expand"/>
            <xsl:with-param name="list-type" select="$list-type"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="*[1][contains(@class,' task/stepsection ')] and not(*[contains(@class,' task/stepsection ')][2])">
          <!-- Stepsection is first, no other appearances -->
          <xsl:apply-templates select="*[contains(@class,' task/stepsection ')]"/>
          <xsl:apply-templates select="." mode="step-elements-with-no-stepsection">
            <xsl:with-param name="step_expand" select="$step_expand"/>
            <xsl:with-param name="list-type" select="$list-type"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <!-- Stepsection elements mixed in with steps -->
          <xsl:apply-templates select="." mode="step-elements-with-stepsection">
            <xsl:with-param name="step_expand" select="$step_expand"/>
            <xsl:with-param name="list-type" select="$list-type"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </section>
  </xsl:template>
  
  <xsl:template match="*" mode="step-elements-with-no-stepsection">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type"/>
    <xsl:call-template name="setaname"/>
    <xsl:element name="{$list-type}">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates select="*[contains(@class,' task/step ')]" mode="steps">
        <xsl:with-param name="step_expand" select="$step_expand"/>
      </xsl:apply-templates>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="*" mode="step-elements-with-stepsection">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type"/>
    <xsl:for-each select="*">
      <xsl:choose>
        <xsl:when test="contains(@class,' task/stepsection ')">
          <xsl:apply-templates select="."/>
        </xsl:when>
        <xsl:when test="contains(@class,' task/step ') and preceding-sibling::*[1][contains(@class,' task/step ')]">
          <!-- Do nothing, was pulled in through recursion -->
        </xsl:when>
        <xsl:otherwise>
          <!-- First step in a series of steps -->
          <xsl:element name="{$list-type}">
            <xsl:for-each select=".."><xsl:call-template name="commonattributes"/></xsl:for-each>
            <xsl:if test="$list-type='ol' and preceding-sibling::*[contains(@class,' task/step ')]">
              <!-- Restart numbering for ordered steps that were interrupted by stepsection.
                   The start attribute is valid in XHTML 1.0 Transitional, but not for XHTML 1.0 Strict.
                   It is possible (preferable) to keep stepsection within an <li> and use CSS to
                   fix numbering, but with testing in March of 2009, this does not work in IE. 
                   It is possible in Firefox 3. -->
              <xsl:attribute name="start"><xsl:value-of select="count(preceding-sibling::*[contains(@class,' task/step ')])+1"/></xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="." mode="steps">
              <xsl:with-param name="step_expand" select="$step_expand"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="following-sibling::*[1][contains(@class,' task/step ')]" mode="sequence-of-steps">
              <xsl:with-param name="step_expand" select="$step_expand"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*" mode="sequence-of-steps">
    <xsl:param name="step_expand"/>
    <xsl:apply-templates select="." mode="steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="following-sibling::*[1][contains(@class,' task/step ')]" mode="sequence-of-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepsection ')]">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps-unordered ')]" name="topic.task.steps-unordered">
    <!-- If there's a block element somewhere in the step list, expand the whole list -->
    <xsl:variable name="step_expand"> <!-- set & save step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="common-processing-within-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
      <xsl:with-param name="list-type" select="'ul'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- only 1 step - output as a para -->
  <xsl:template match="*[contains(@class,' task/step ')]" mode="onestep">
    <xsl:param name="step_expand"/>
    <div class="p">
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class" select="'p'"/>
      </xsl:call-template>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <!-- multiple steps - output as list items -->
  <!-- 3517050: move rev test into mode="steps-fmt" to avoid wrapping <li> in another element.
       Can deprecate this template which now simply passes processing on to steps-fmt? -->
  <xsl:template match="*[contains(@class,' task/step ')]" mode="steps">
    <xsl:param name="step_expand"/>
    <li>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class"><xsl:if test="$step_expand='yes'">stepexpand</xsl:if></xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates><xsl:with-param name="step_expand" select="$step_expand"/></xsl:apply-templates>
    </li>  
  </xsl:template>
  
  <xsl:template match="*" mode="add-step-importance-flag">
    <xsl:choose>
      <xsl:when test="@importance='optional'">
        <strong>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Optional'"/>
          </xsl:call-template>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'ColonSymbol'"/>
          </xsl:call-template><xsl:text> </xsl:text>
        </strong>
      </xsl:when>
      <xsl:when test="@importance='required'">
        <strong>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Required'"/>
          </xsl:call-template>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'ColonSymbol'"/>
          </xsl:call-template><xsl:text> </xsl:text>
        </strong>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
    
    <xsl:template match="*[contains(@class, ' task/cmd ')]" name="topic.task.cmd">
      <xsl:choose>
        <xsl:when test="@href and @keyref">
          <xsl:apply-templates select="." mode="turning-to-link">
            <xsl:with-param name="keys" select="@keyref"/>
            <xsl:with-param name="type" select="'ph'"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <span>
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="setidaname"/> 
            <xsl:apply-templates/>  
          </span>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="add-br-for-empty-cmd"/>
    </xsl:template>
    
    <xsl:template name="add-br-for-empty-cmd">
      <xsl:if test="string-length(normalize-space(.)) = 0">
        <br/>
      </xsl:if>
    </xsl:template>
  
  <!-- nested steps - 1 level of nesting only -->
  <xsl:template match="*[contains(@class, ' task/substeps ')][empty(*[contains(@class,' task/substep ')])]" priority="10"/>
  
  <xsl:template match="*[contains(@class,' task/substeps ')]" name="topic.task.substeps">
   <!-- If there's a block element somewhere in the step list, expand the whole list -->
    <xsl:variable name="sub_step_expand"> <!-- set & save sub_step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <ol>
      <xsl:if test="parent::*/parent::*[contains(@class,' task/steps ')]"> <!-- Is the grandparent an ordered step? -->
        <xsl:attribute name="type">a</xsl:attribute>            <!-- yup, letter these steps -->
      </xsl:if>                                                <!-- otherwise, default to numbered -->
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates>
        <xsl:with-param name="sub_step_expand" select="$sub_step_expand"/>
      </xsl:apply-templates>
    </ol>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- 3517050 move rev test into mode="steps-fmt" to avoid wrapping <li> in another element.
       Can deprecate this template which now simply passes processing on to substep-fmt? -->
  <xsl:template match="*[contains(@class,' task/substep ')]" name="topic.task.substep">
    <xsl:param name="sub_step_expand"/>
    <li>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class"><xsl:if test="$sub_step_expand='yes'">substepexpand</xsl:if></xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates>
        <xsl:with-param name="sub_step_expand"/>
      </xsl:apply-templates>
    </li>
  </xsl:template>
  
  <!-- choices contain choice items -->
  <xsl:template match="*[contains(@class, ' task/choices ')][empty(*[contains(@class,' task/choice ')])]" priority="10"/>
  
  <xsl:template match="*[contains(@class,' task/choices ')]" name="topic.task.choices">
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <ul>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates/>
    </ul>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- task/choice - fall-thru -->

  <!-- choice table is like a simpletable - 2 columns, set heading -->
  <xsl:template match="*[contains(@class,' task/choicetable ')]" name="topic.task.choicetable">
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <table border="1" frame="hsides" rules="rows" cellpadding="4" cellspacing="0" summary="" class="choicetableborder">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="generate-table-summary-attribute"/>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="dita2html:simpletable-cols"/>
      <!--If the choicetable has no header - output a default one-->
      <xsl:variable name="chhead" as="element()?">
        <xsl:choose>
          <xsl:when test="exists(*[contains(@class,' task/chhead ')])">
            <xsl:sequence select="*[contains(@class,' task/chhead ')]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="gen" as="element(gen)?">
              <xsl:call-template name="gen-chhead"/>
            </xsl:variable>
            <xsl:sequence select="$gen/*"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:apply-templates select="$chhead"/>
      <tbody>
        <xsl:apply-templates select="*[contains(@class, ' task/chrow ')]"/>
      </tbody>
    </table>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
    
  <xsl:template match="*[contains(@class,' task/choicetable ')]" mode="get-output-class">choicetableborder</xsl:template>
    <xsl:template match="*[contains(@class,' task/choicetable ')]" mode="dita2html:get-max-entry-count" as="xs:integer">
      <xsl:sequence select="2"/>
    </xsl:template>
   
    <!-- Generate default choicetable header -->
    <xsl:template name="gen-chhead" as="element(gen)?">
      <!-- Generated header needs to be wrapped in gen element to allow correct language detection -->
      <gen>
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <chhead class="- topic/sthead task/chhead ">
         <choptionhd class="- topic/stentry task/choptionhd ">
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Option'"/>
           </xsl:call-template>
         </choptionhd>  
         <chdeschd class="- topic/stentry task/chdeschd ">
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Description'"/>
           </xsl:call-template>
         </chdeschd>
        </chhead>
      </gen>
    </xsl:template>
   
  <xsl:template match="*[contains(@class,' task/chhead ')]">
    <thead>
      <tr>
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
        <xsl:apply-templates select="*[contains(@class,' task/choptionhd ')]"/>
        <xsl:apply-templates select="*[contains(@class,' task/chdeschd ')]"/>
      </tr>
    </thead>
  </xsl:template>
    
  <xsl:template match="*[contains(@class,' task/choptionhd ')]">
    <th scope="col">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="style">
        <xsl:with-param name="contents">
          <xsl:text>vertical-align:bottom;</xsl:text>
          <xsl:call-template name="th-align"/>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:apply-templates select="." mode="chtabhdr"/>
    </th>
  </xsl:template>
    
  <xsl:template match="*[contains(@class,' task/chdeschd ')]">
    <th scope="col">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="style">
        <xsl:with-param name="contents">
          <xsl:text>vertical-align:bottom;</xsl:text>
          <xsl:call-template name="th-align"/>
        </xsl:with-param>
      </xsl:call-template>
      <xsl:apply-templates select="." mode="chtabhdr"/>
    </th>
  </xsl:template>
  
  <!-- Option & Description headers -->
  <xsl:template match="*[contains(@class,' task/choptionhd ')]" mode="chtabhdr">
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
    
  <xsl:template match="*[contains(@class,' task/chdeschd ')]" mode="chtabhdr">
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/chrow ')]" name="topic.task.chrow">
   <tr>
     <xsl:call-template name="setid"/>
     <xsl:call-template name="commonattributes"/>    
      <xsl:apply-templates/>
   </tr>
  </xsl:template>
  
  <!-- specialization of stentry - choption -->
  <!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
  <!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
  <xsl:template match="*[contains(@class,' task/choption ')]" name="topic.task.choption">
    <xsl:variable name="localkeycol" as="xs:integer">
      <xsl:choose>
        <xsl:when test="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol">
          <xsl:value-of select="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol"/>
        </xsl:when>
        <xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>  
    <xsl:variable name="element-name" select="if ($localkeycol = 1) then 'th' else 'td'"/>
    <xsl:element name="{$element-name}">
      <xsl:call-template name="setid"/>
      <xsl:call-template name="style">
        <xsl:with-param name="contents">
          <xsl:text>vertical-align:top;</xsl:text>     
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="$localkeycol = 1">
        <xsl:attribute name="scope">row</xsl:attribute>
      </xsl:if>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:call-template name="stentry-templates"/>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </xsl:element>
  </xsl:template>
  
  <!-- specialization of stentry - chdesc -->
  <!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
  <!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
  <xsl:template match="*[contains(@class,' task/chdesc ')]" name="topic.task.chdesc">
    <xsl:variable name="localkeycol" as="xs:integer">
      <xsl:choose>
        <xsl:when test="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol">
          <xsl:value-of select="ancestor::*[contains(@class,' topic/simpletable ')][1]/@keycol"/>
        </xsl:when>
        <xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>  
    <xsl:variable name="element-name" select="if ($localkeycol = 2) then 'th' else 'td'"/>
    <xsl:element name="{$element-name}">
      <xsl:call-template name="setid"/>
      <xsl:call-template name="style">
        <xsl:with-param name="contents">
          <xsl:text>vertical-align:top;</xsl:text>     
        </xsl:with-param>
      </xsl:call-template>
      <xsl:if test="$localkeycol = 2">
        <xsl:attribute name="scope">row</xsl:attribute>
      </xsl:if>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:call-template name="stentry-templates"/>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepxmp ')]" name="topic.task.stepxmp">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepresult ')]" name="topic.task.stepresult">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/info ')]" name="topic.task.info">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/tutorialinfo ')]" name="topic.task.tutorialinfo">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template name="generateItemGroupTaskElement">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/prereq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_prereq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/context ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_context'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
      
  <xsl:template match="*[contains(@class,' task/result ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_results'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/postreq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_postreq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/taskbody ')]/*[contains(@class,' topic/example ')]">
    <section>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="gen-toc-id"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:apply-templates select="." mode="dita2html:section-heading"/>
      <xsl:apply-templates select="node() except *[contains(@class, ' topic/title ')]"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </section>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/taskbody ')]/*[contains(@class,' topic/example ')][not(*[contains(@class,' topic/title ')])]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_example'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!-- 
       To override the task label for a specific element, match that element with this mode. 
       For example, you can turn off labels for <context> with this rule:
       <xsl:template match="*[contains(@class,' task/context ')]" mode="generate-task-label"/>
  -->
  <xsl:template match="*" mode="generate-task-label">
    <xsl:param name="use-label"/>
    <xsl:if test="$GENERATE-TASK-LABELS='YES'">
      <xsl:variable name="headLevel">
        <xsl:variable name="headCount" select="count(ancestor::*[contains(@class,' topic/topic ')]) + 1"
          as="xs:integer"/>
        <xsl:choose>
          <xsl:when test="$headCount > 6">h6</xsl:when>
          <xsl:otherwise>h<xsl:value-of select="$headCount"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <div class="tasklabel">
        <xsl:element name="{$headLevel}">
          <xsl:attribute name="class">sectiontitle tasklabel</xsl:attribute>
          <xsl:value-of select="$use-label"/>
        </xsl:element>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- Tasks have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group"
                name="related-links:group.task"
                as="xs:string">
    <xsl:text>task</xsl:text>
  </xsl:template>
  
  <!-- Priority of task group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group-priority"
                name="related-links:group-priority.task"
                as="xs:integer">
    <xsl:sequence select="2"/>
  </xsl:template>
  
  <!-- Task wrapper for HTML: "Related tasks" in <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:result-group"
                name="related-links:result.task" as="element()">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo reltasks">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related tasks'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>

  <xsl:include href="plugin:org.dita.html5:xsl/choicetable.xsl"/>

</xsl:stylesheet>
