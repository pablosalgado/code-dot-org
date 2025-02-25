/** @file Header banner and start new project buttons for the project gallery */
import PropTypes from 'prop-types';
import React from 'react';
import i18n from '@cdo/locale';
import StartNewProject from '@cdo/apps/templates/projects/StartNewProject';
import HeaderBanner from '@cdo/apps/templates/HeaderBanner';
import ProjectsPromo from './ProjectsPromo';

export default class ProjectHeader extends React.Component {
  static propTypes = {
    canViewAdvancedTools: PropTypes.bool,
    projectCount: PropTypes.number
  };

  render() {
    // Verify background image works for both LTR and RTL languages.
    const backgroundUrl = '/shared/images/banners/project-banner.jpg';
    return (
      <div>
        <HeaderBanner
          short={true}
          headingText={i18n.projects()}
          subHeadingText={i18n.projectsSubHeadingMillions({
            project_count: this.props.projectCount
          })}
          backgroundUrl={backgroundUrl}
        />
        <div className={'container main'}>
          <ProjectsPromo />
          <StartNewProject
            canViewFullList
            canViewAdvancedTools={this.props.canViewAdvancedTools}
          />
        </div>
      </div>
    );
  }
}
